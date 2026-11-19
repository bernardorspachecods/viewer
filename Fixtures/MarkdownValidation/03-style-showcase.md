---
title: Markdown style showcase
description: One document with every Markdown style, to compare the preview and the editor.
tags: [style, preview, editor]
---

# Style showcase

Switch between the preview and the **Markdown Editor** button: nothing should move or change look. This paragraph is long enough to wrap across the whole width of the window, so the line height and the wrapping can be compared between both views.

A second paragraph right after, with **bold**, *italic*, ***both***, ~~struck~~, `inline code`, a [web link](https://example.com), a [local link](./outro-ficheiro.md), and an inline comment <!-- a note that only shows its text --> in the middle of a sentence.

## Headings

### Third level

#### Fourth level

##### Fifth level

###### Sixth level

## Inline formulas and block formulas

Energy: $E = mc^2$. A fraction: $\frac{1}{2}$. Subscripts and operators: $\alpha_i \leq \beta^2$, and a sum $\sum_{i=1}^{n} i$ inside a sentence.

$$
\frac{-b + \sqrt{b^2 - 4ac}}{2a}
$$

$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$

## Lists

- bullet one
- bullet two with `code` and a [link](https://example.com)
  - nested bullet
    - third level

1. ordered one
2. ordered two
   1. nested ordered
3. ordered three

- [ ] open task
- [ ] done task

## Quotes

> A block quote with **bold** and a [link](https://example.com).
>
> A second paragraph in the same quote.

## Tables

| Name | Centered | Right |
| --- | :---: | ---: |
| alpha | 1 | first |
| beta | 22 | second `code` |
| gamma with a longer value that has to wrap inside its column when the window is narrow | 333 | third |

## Code

```swift
struct Greeter {
    let name: String
    func greet() -> String { "Hello, \(name)!" }  // a comment
}
print(Greeter(name: "Viewer").greet(), 42)
```

```python
def total(values):
    return sum(v * 2 for v in values if v > 0)
```

```json
{ "name": "viewer", "open": true, "count": 3 }
```

## Images and rules

![Local validation diagram](images/local-diagram.svg "Local SVG image")

---

Text with <kbd>kbd</kbd> and <mark>mark</mark> HTML tags, which the editor can only show as source.

Last paragraph.
