English | [日本語](./README.ja.md)

# DInterface

DInterface is a Godot 4 plugin for introducing interface mechanisms into GDScript.
It automatically generates bridge scripts from custom definition files with the `.ifc` extension, supporting robust design without relying solely on dynamic duck typing.

## Features

- **Definition via .ifc**: Declare interfaces in dedicated definition files (`.ifc`).
- **Automatic Bridge Script Generation**: Automatically generates GDScript from definition files to wrap and call interfaces.
- **Automatic Boilerplate Injection**: Automatically injects implementation stubs and boilerplate into GDScripts using the `# implements` marker.
- **Documentation Support**: Documentation comments (`##`) in `.ifc` files are preserved in the generated scripts.
- **Powerful Validation**:
    - Detects mismatches in method argument count, types, and return types.
    - Validates property type matches.
    - Validates signal argument configurations.
    - Type checking considering inheritance relationships of engine classes and custom classes (`class_name`).
- **Casting Feature**: Wrap objects into interface types using `IInterface.cast(object)` or `IInterface.cast_checked(object)`.
- **External Editor Integration**: Use your favorite external editors (VSCode, Neovim, etc.) to edit definition files.

## Usage

### 1. Defining an Interface

Create an `.ifc` file and define the interface.
The syntax is similar to GDScript, allowing you to define properties, methods, signals, and enums.

```gdscript
# i_mover.ifc
enum MoveType { WALK, RUN }

## The movement speed of the object.
var speed: float
## Emitted when the object moves.
signal moved(position: Vector2)

## Moves the object by delta.
func move(delta: float) -> void
func get_type() -> MoveType
```

When you save the file, the plugin automatically generates `i_mover.gd` with the `class_name` `IMover`.

### 2. Implementing the Interface

#### Method A: Automatic Injection (Recommended)
Add a comment `# implements <InterfaceName>` at the top of your script. When you save or reload, the plugin will automatically inject the necessary boilerplate.

```gdscript
# player.gd
extends CharacterBody2D

# implements IMover
```

#### Method B: Manual Implementation
Implement the members defined by the interface in any script.
Also, define `static func implements_list() -> Array[Script]` to return the interfaces (generated bridge scripts) that the script implements.

```gdscript
# player.gd
extends CharacterBody2D

# List of implemented interfaces
static func implements_list() -> Array[Script]:
    return [IMover]

var speed: float = 200.0
signal moved(position: Vector2)

func move(delta: float) -> void:
    # Movement logic
    emit_signal("moved", global_position)

func get_type() -> int:
    return IMover.MoveType.WALK
```

### 3. Using the Interface

To treat an object as an interface, use the `cast` or `cast_checked` method of the generated class.

```gdscript
# some_system.gd
func do_something(target: Object):
    # Returns null if not implemented
    var mover = IMover.cast(target)
    if mover:
        mover.move(0.1)

    # Asserts that the object implements the interface
    var forced_mover = IMover.cast_checked(target)
    forced_mover.move(0.1)
```

## Advanced: Implementation Delegation

If you want to delegate the implementation to another object instead of the object itself, implement the `get_implementer(interface_script: Script) -> Object` method.

```gdscript
func get_implementer(t_if: Script) -> Object:
    if t_if == IMover:
        return $MoverComponent
    return self
```

## Editor Settings

Configurable in the `d_interface/check` section of `Editor Settings`.

- **Auto Check On Reload**: Automatically validates interface implementation when scripts are saved and outputs errors if there are issues.
- **Auto Generate Bridge On Save**: Automatically generates `.gd` bridge files when `.ifc` files are saved.
- **Auto Inject Boilerplate On Reload**: Automatically injects interface boilerplate based on the `# implements` marker.

## Notes

- Bridge scripts (`.gd`) are automatically generated and should not be edited manually.
- When using an external editor, editing the `.ifc` file will trigger automatic synchronization.

## Installation

1. Place the `addons/d_interface` folder into your project's `addons` folder.
2. Enable `DInterface` from `Project Settings` > `Plugins`.
