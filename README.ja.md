[English](./README.md) | 日本語

# DInterface

DInterface は、GDScript にインターフェースの仕組みを導入するための Godot 4 向けプラグインである。
`.ifc` という独自形式の定義ファイルからブリッジ用のスクリプトを自動生成し、動的なダックタイピングに頼らない堅牢な設計を支援する。

## 特徴

- **.ifc による定義**: 専用の定義ファイル（`.ifc`）でインターフェースを宣言できる。
- **ブリッジスクリプトの自動生成**: 定義ファイルから、インターフェースをラップして呼び出すための GDScript を自動で生成する。
- **ボイラープレートの自動注入**: `# implements` マーカーを使用することで、実装用のスタブやボイラープレートを GDScript に自動挿入する。
- **ドキュメントコメントの継承**: `.ifc` ファイル内の `##` で始まるドキュメントコメントを生成スクリプトに引き継ぐ。
- **強力な検証機能**:
    - メソッドの引数の数、型、戻り値の型の不一致を検出。
    - プロパティの型一致を検証。
    - シグナルの引数構成を検証。
    - エンジンクラスおよびカスタムクラス（`class_name`）の継承関係を考慮した型チェック。
- **キャスト機能**: `IInterface.cast(object)` または `IInterface.cast_checked(object)` のような形式で、オブジェクトをインターフェース型にラップできる。
- **外部エディタ連携**: 定義ファイルの編集に使い慣れた外部エディタ（VSCode, Neovim 等）を使用可能。

## 使い方

### 1. インターフェースの定義

`.ifc` ファイルを作成し、インターフェースを定義する。
文法は GDScript に似ており、プロパティ、メソッド、シグナル、列挙型（enum）を定義できる。

```gdscript
# i_mover.ifc
enum MoveType { WALK, RUN }

## オブジェクトの移動速度。
var speed: float
## オブジェクトが移動した際に発行される。
signal moved(position: Vector2)

## デルタ時間分だけオブジェクトを移動させる。
func move(delta: float) -> void
func get_type() -> MoveType
```

ファイルを保存すると、プラグインが `IMover` という `class_name` を持つ `i_mover.gd` を自動生成する。

### 2. インターフェースの実装

#### 方法A：自動注入（推奨）
スクリプトの冒頭に `# implements <InterfaceName>` というコメントを記述する。保存またはリロード時に、必要なボイラープレートが自動的に挿入される。

```gdscript
# player.gd
extends CharacterBody2D

# implements IMover
```

#### 方法B：手動実装
任意のスクリプトで、インターフェースが定義しているメンバを実装する。
また、`static func implements_list() -> Array[Script]` を定義して、実装しているインターフェース（自動生成されたブリッジスクリプト）を返すようにする。

```gdscript
# player.gd
extends CharacterBody2D

# 実装するインターフェースのリスト
static func implements_list() -> Array[Script]:
    return [IMover]

var speed: float = 200.0
signal moved(position: Vector2)

func move(delta: float) -> void:
    # 移動処理
    emit_signal("moved", global_position)

func get_type() -> int:
    return IMover.MoveType.WALK
```

### 3. インターフェースの使用

オブジェクトをインターフェースとして扱いたい場合は、自動生成されたクラスの `cast` または `cast_checked` メソッドを使用する。

```gdscript
# some_system.gd
func do_something(target: Object):
    # 実装していない場合は null を返す
    var mover = IMover.cast(target)
    if mover:
        mover.move(0.1)

    # 実装していることを前提とし、失敗時にアサートする
    var forced_mover = IMover.cast_checked(target)
    forced_mover.move(0.1)
```

## 応用：実装の委譲（Delegation）

オブジェクト自身ではなく、保持している別のオブジェクトに実装を委譲したい場合は、`get_implementer(interface_script: Script) -> Object` メソッドを実装する。

```gdscript
func get_implementer(t_if: Script) -> Object:
    if t_if == IMover:
        return $MoverComponent
    return self
```

## エディタ設定

`Editor Settings` の `d_interface/check` セクションで設定可能。

- **Auto Check On Reload**: スクリプト保存時などに自動でインターフェースの実装検証を行い、不備があればエラーを出力する。
- **Auto Generate Bridge On Save**: `.ifc` ファイル保存時に `.gd` ブリッジファイルを自動生成する。
- **Auto Inject Boilerplate On Reload**: `# implements` マーカーに基づき、インターフェースのボイラープレートを自動注入する。

## 注意事項

- ブリッジスクリプト（`.gd`）は自動生成されるため、手動で編集してはならない。
- 外部エディタを使用している場合、`.ifc` ファイルを編集すると自動的に同期される。

## インストール

1. `addons/d_interface` フォルダをプロジェクトの `addons` フォルダに配置する。
2. `Project Settings` > `Plugins` から `DInterface` を有効にする。
