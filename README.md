# MenuTodo

A lightweight macOS menubar todo app. No Dock icon — lives in the menu bar
as a checklist icon that shows the count of open todos.

## Build

    ./build.sh
    open build/MenuTodo.app

Or drag `build/MenuTodo.app` to `/Applications`.

## Data

Todos are stored as JSON at `~/Library/Application Support/MenuTodo/todos.json`.

## Develop in Xcode

    xcodegen generate && open MenuTodo.xcodeproj
