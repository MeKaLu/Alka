# Alka
Game engine written in zig, compatible with **master branch**.

You may need these to compile the engine
`sudo apt install libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev`

Get started [work in progress]()

[Documentation]()

## Project goals
- [x] Single window operations
- [x] Input management
- [x] Asset manager
- 2D Renderer:
    - [x] Camera
    - [1/2] Shape drawing
    - [x] Texture drawing
    - [1/2] Custom batch system 
    - [1/2] Text drawing 
    - [ ] GUI system
    - [ ] Optional: Vulkan implementation
- [ ] Audio
- [ ] Optional: Android support
- [ ] Optional: Simple ecs
- [ ] Optional: Scripting language 
- [ ] Optional: Data packer 

## About release cycle
* Versioning: major.minor.patch
* Every x.x.3 creates a new minor, which becomes x.(x + 1).0
* Again every x.3.x creates a new major, which becomes (x + 1).0.x
* When a new version comes, it'll comitted as x.x.x source update
