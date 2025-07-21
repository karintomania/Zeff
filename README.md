# Zeff - Zig Emoji Fuzzy Finder

Zeff is a blazing-fast command-line interface (CLI) tool that helps you quickly find emojis using fuzzy and keyword-based searches.

![Image](https://github.com/user-attachments/assets/bc67eb49-4f1d-41e5-affe-bcef479bdaa8)

---

# Background

I'm an Ubuntu user, and I love Ubuntu. However, it doesn't come with the right tool to find emojis. (Yes, there is a default "Characters" app, but you have to know the official name of the emoji, which I rarely do.)
I constantly find myself opening a browser and searching on Google just to copy and paste an emoji. I wanted something fast and easily accessible from my terminal. That's why I built Zeff.

# Why Choose Zeff?

## 🚀 Blazing Fast & Lightweight

Thanks to Zig, the binary size of Zeff is under 300KB, and it consumes minimal memory (about 2MB on my machine).

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

Zeff requires `ncurses` to be installed on your system. You can typically install it using your distribution's package manager. Here's an example for Ubuntu:

```bash
sudo apt-get install libncurses5-dev libncursesw5-dev
```

## Install
Currently, Zeff is only available by building the binary from the source code.
Clone this repo and run `make build`. The binary will be in `zig-out/bin/zeff`.

**Note:** You need zig v0.14.1 to build.

# Special Thanks!
The fuzzy search algorithm is heavily inspired by this excellent repo: https://github.com/philj56/fuzzy-match by @philj56.

# TODOs
- [ ] Improve keywords  
- [ ] Skin tones  
- [ ] Search history  

