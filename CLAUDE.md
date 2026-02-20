# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Zig-based emoji finder application that parses emoji data from a TSV file and provides emoji information including character, category, subcategory, name, keywords, and skin tone variations.

## Core Architecture

The application consists of two main modules:
- `src/main.zig`: Entry point that reads `input.tsv` and processes emoji data line by line
- `src/emoji.zig`: Core `Emoji` struct and parsing logic that handles TSV parsing and memory management

The `Emoji` struct contains:
- `character`: The actual emoji character
- `category`: Main category (e.g., "Smileys & Emotion")  
- `subcategory`: Specific subcategory (e.g., "face-smiling")
- `name`: Human-readable name
- `keywords`: Array of searchable keywords
- `skin_tones`: Array of skin tone variations

## Common Commands

### Build and Run
```bash
# Build the project
zig build

# Run the application
zig build run

# Build and run with file watching (development)
make run-watch
```

### Testing
```bash
# Run all unit tests
zig build test

# Run tests with file watching
make test-watch
```

### Development
```bash
# Format source code
make format

# Build with file watching
make build-watch
```

## Input Data Format

The application expects `input.tsv` in the root directory with tab-separated values:
```
[emoji_character]	[category]	[subcategory]	[name]	[keywords_comma_separated]	[skin_tones_tab_separated]
```

## Memory Management

The `Emoji` struct uses dynamic allocation for keywords and skin tones arrays. Always call `emoji.deinit(allocator)` to free allocated memory when done with an emoji instance.

## Build Configuration

- Uses Zig's standard build system with `build.zig`
- Minimum Zig version: 0.15.1
- Package name: `emoji_finider`
- Builds executable named `emoji_finider`
- Includes unit tests for core functionality
