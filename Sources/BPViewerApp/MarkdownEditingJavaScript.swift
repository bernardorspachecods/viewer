import SwiftUI
import WebKit
import BPViewerCore
import AppKit

enum MarkdownEditingJavaScript {
    static let source = #"""
    (() => {
      const handler = () => window.webkit?.messageHandlers?.bpViewerMarkdownEdit;
      const unitSelector = '[data-bp-block-id][data-bp-editable="true"]';
      const blockedSelector = 'img, math, [data-bp-special-kind]';
      const commitDelay = 120;
      const styleID = 'bp-inline-style';
      const styleSource = `
        [contenteditable="plaintext-only"] {
          cursor: text;
          outline: none;
          border-radius: 4px;
          transition: background-color 120ms ease;
        }
        [contenteditable="plaintext-only"]:hover {
          background: color-mix(in srgb, -apple-system-blue 4%, transparent);
        }
        [contenteditable="plaintext-only"]:focus {
          background: color-mix(in srgb, -apple-system-blue 8%, transparent);
        }
      `;
      let enabled = false;
      let entries = [];
      let pendingEntry = null;
      let commitTimer = null;

      const isTextBlock = (tag) => tag === 'P' || /^H[1-6]$/.test(tag);
      const isList = (tag) => tag === 'UL' || tag === 'OL';
      const isSupported = (element) => !element.matches(blockedSelector) && !element.querySelector(blockedSelector);

      function collectEntries() {
        const collected = [];
        document.querySelectorAll(unitSelector).forEach((block) => {
          if (isTextBlock(block.tagName)) {
            if (isSupported(block)) {
              collected.push({ element: block, blockID: block.dataset.bpBlockId, unitIndex: null });
            }
          } else if (isList(block.tagName)) {
            block.querySelectorAll('li').forEach((item, index) => {
              if (item.querySelector('ul, ol') || !isSupported(item)) return;
              collected.push({ element: item, blockID: block.dataset.bpBlockId, unitIndex: index });
            });
          }
        });
        return collected;
      }

      function unitText(element) {
        const clone = element.cloneNode(true);
        clone.querySelectorAll('ul, ol, input').forEach((node) => node.remove());
        return clone.textContent.replace(/ /g, ' ').trim();
      }

      function textNodes(element) {
        const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
        const nodes = [];
        while (walker.nextNode()) nodes.push(walker.currentNode);
        return nodes;
      }

      function textLength(element) {
        return textNodes(element).reduce((total, node) => total + node.length, 0);
      }

      function entryFor(target) {
        return entries.find((entry) => entry.element.contains(target)) || null;
      }

      function commit(entry) {
        if (!entry.element.isConnected) return;
        const text = unitText(entry.element);
        if (text === entry.baseline) return;
        handler()?.postMessage({
          type: 'inlineChange',
          blockID: entry.blockID,
          unitIndex: entry.unitIndex,
          original: entry.baseline,
          text
        });
        entry.baseline = text;
      }

      function flush() {
        clearTimeout(commitTimer);
        commitTimer = null;
        const entry = pendingEntry;
        pendingEntry = null;
        if (entry) commit(entry);
      }

      function scheduleCommit(entry) {
        pendingEntry = entry;
        clearTimeout(commitTimer);
        commitTimer = setTimeout(flush, commitDelay);
      }

      function setEnabled(on) {
        flush();
        enabled = on;
        entries.forEach((entry) => { entry.element.contentEditable = 'false'; });
        entries = on ? collectEntries() : [];
        entries.forEach((entry) => {
          entry.baseline = unitText(entry.element);
          entry.element.contentEditable = 'plaintext-only';
        });
        const existing = document.getElementById(styleID);
        if (on && !existing) {
          const style = document.createElement('style');
          style.id = styleID;
          style.textContent = styleSource;
          document.head.append(style);
        } else if (!on && existing) {
          existing.remove();
        }
      }

      function placeCaret(element, offset) {
        const range = document.createRange();
        range.selectNodeContents(element);
        range.collapse(false);
        let remaining = Math.max(offset, 0);
        for (const node of textNodes(element)) {
          if (remaining <= node.length) {
            range.setStart(node, remaining);
            range.collapse(true);
            break;
          }
          remaining -= node.length;
        }
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
      }

      function focusAt(blockID, renderedTextOffset) {
        const candidates = entries.filter((entry) => entry.blockID === blockID);
        if (candidates.length === 0) return;
        const entry = candidates.find((candidate) => textLength(candidate.element) >= renderedTextOffset)
          || candidates[0];
        entry.element.focus();
        placeCaret(entry.element, renderedTextOffset);
      }

      document.addEventListener('dblclick', (event) => {
        if (enabled) return;
        event.preventDefault();
        const block = event.target?.closest?.('[data-bp-block-id]');
        const range = document.caretRangeFromPoint?.(event.clientX, event.clientY);
        let renderedTextOffset = null;
        if (block && range) {
          const measuredRange = document.createRange();
          try {
            measuredRange.selectNodeContents(block);
            measuredRange.setEnd(range.startContainer, range.startOffset);
            renderedTextOffset = measuredRange.toString().length;
          } catch (_) {
            renderedTextOffset = null;
          }
        }
        handler()?.postMessage({
          type: 'begin',
          mode: 'markdown',
          text: '',
          blockID: block?.dataset.bpBlockId || null,
          renderedTextOffset
        });
      });

      document.addEventListener('input', (event) => {
        const entry = entryFor(event.target);
        if (entry) scheduleCommit(entry);
      });

      document.addEventListener('focusout', (event) => {
        if (entryFor(event.target)) flush();
      });

      document.addEventListener('keydown', (event) => {
        if (!enabled) return;
        if (event.key === 'Enter' && !event.isComposing && entryFor(event.target)) {
          event.preventDefault();
          return;
        }
        if (!event.metaKey || event.isComposing) return;
        const key = event.key.toLowerCase();
        if (key === 'z') {
          event.preventDefault();
          flush();
          handler()?.postMessage({ type: event.shiftKey ? 'redo' : 'undo', text: '' });
        } else if (key === 'b' || key === 'i' || key === 'u') {
          event.preventDefault();
        }
      });

      window.bpInline = { setEnabled, focusAt };
    })();
    """#
}
