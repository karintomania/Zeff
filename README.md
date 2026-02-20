# Zeff - Zig Emoji Fuzzy Finder

Zeff is a blazing-fast command-line interface (CLI) tool that helps you quickly find emojis using fuzzy and keyword-based searches.

![Image](https://github.com/user-attachments/assets/bc67eb49-4f1d-41e5-affe-bcef479bdaa8)

## Update at 2025/08/07 🎉
Skin tone picker is added to Zeff ✋✋🏻✋🏽✋🏿  
<img width="500" height="500" alt="Image" src="https://github.com/user-attachments/assets/8517da33-a90f-4259-9d2a-7b2b1982d868" />

---

# Background

I'm an Ubuntu user, and I love Ubuntu. However, it doesn't come with the right tool to find emojis. (Yes, there is a default "Characters" app, but you have to know the official name of the emoji, which I rarely do.)
I constantly find myself opening a browser and searching on Google just to copy and paste an emoji. I wanted something fast and easily accessible from my terminal. That's why I built Zeff.

# Why Choose Zeff?

## 🚀 Blazing Fast & Lightweight

Thanks to Zig, the binary size of Zeff is roughly 300KB, and it consumes minimal memory (about 2MB on my machine).

## ✨ Smart Fuzzy & Keyword Search

Zeff supports fuzzy search, which allows you to make typos during your search.

Additionally, Zeff uses keywords alongside the emoji's official name to search.  
For example, you can find the 🤪 emoji by simply searching for "crazy," even though its official name is "zany face", which most people don't know.

## 💻 Simple CLI Tool

You can use Zeff directly from your terminal without any GUI.
Because it prints the result on stdout, you can pipe Zeff or use it with a command substitution.

```
# Copy the selected emoji to clipboard
zeff | wl-copy

# Use emoji in the commit message
 git commit -m "Update readme $(zeff)"
```

# How to Use

## Prerequisites

The only dependency Zeff needs is `libc`, so you don't really need anything extra to install.

## Install
### Pre-built Binary
Pre-built bninaries for Linux (x86_64) and macOS (arm64) is available from the [release page](https://github.com/karintomania/Zeff/releases).


### Build from source
Clone this repo and run `make build`. The binary will be in `zig-out/bin/zeff`.

**Note:** You need zig v0.15.1 to build.

# Special Thanks!
The fuzzy search algorithm is heavily inspired by this excellent repo: https://github.com/philj56/fuzzy-match by @philj56.  
Zeff uses [termbox2](https://github.com/termbox/termbox2) internallly as a CLI library.  

# TODOs
- [ ] Improve keywords  
- [x] Skin tones  
- [ ] Search history  

