# Michem

基于 [Chitin](https://github.com/chitin-dev/chitin) 的 Typst 化学绘图包。
`chitin-chem` 负责化学图与 SMILES，`chitin-chemdraw` 负责二维布局、描绘和 SVG，
编译为 `wasm32-unknown-unknown`，通过 Typst minimal plugin protocol 调用。

项目结构参考 clio：Rust core、WASM 边界、Typst 接口分别维护。

## 构建

需要 Rust（支持 edition 2024）、Typst 0.14+，以及 WASM 编译目标：

```bash
rustup target add wasm32-unknown-unknown
bash scripts/build-plugin.sh
typst compile --root . examples/gallery.typ
typst compile --root . examples/reaction.typ
typst compile --root . examples/anchors.typ
typst compile --root . examples/fonts.typ
typst compile --root . docs/manual.typ
```

Chitin 固定到 `8c7357ff9755466f61c38d52641e74ed2feae352`，即初始化时本地
`/home/ashgrey/Github/chitin` 的提交。正常构建从 GitHub 获取依赖，不依赖绝对路径。
`Cargo.lock` 固定完整依赖树。构建产物为 `wasm/michem.wasm`，分发 Typst 包时必须带上它。

## SMILES

```typst
#import "lib.typ" as michem

#michem.render("CC(=O)Oc1ccccc1C(=O)O", style: michem.style(font: "Libertinus Serif"))
#michem.render("NCC(=O)O", style: michem.style(
  font: "Libertinus Serif",
  bond-length: 30,
  stroke-width: 1,
  bond-colors: "uniform",
  color-map: (O: rgb("#c84545"), N: rgb("#456ac8")),
))
```

支持透明背景、元素配色与单色模式、键长、线宽、字体大小、双键间距、楔形宽度、
芳香环显示和布局预算。调节键长会按比例调整未显式覆盖的描绘尺寸。
字体可直接按名称配置，无需提供字体文件：

```typst
#michem.render("NCC(=O)O", style: michem.style(font: "Libertinus Serif"))
```

`font` 接受 Typst 环境可用的字体族名称。Typst 使用指定字体测量标签，WASM 使用测量结果
完成键线裁剪和标签布局，SVG 通过 `font-family` 使用相同字体。参见 `examples/fonts.typ`。
未设置 `font` 时保留 Chitin 默认的 Noto Sans 轮廓；文档的 `set text` 不改变分子字体。
单独调用 `svg` 或 `diagram` 并指定字体时，需要放在 `context { ... }` 中；
`render` 和 CeTZ 接口会自动处理上下文。独立导出的 SVG 使用字体引用，查看端也需要该字体。

## 手动绘制

```typst
#let ethanol = michem.molecule(
  atoms: (
    michem.atom("a", at: (0, 0)),
    michem.atom("b", at: (0.866, 0.5)),
    michem.atom("oxygen", element: "O", at: (1.732, 0)),
  ),
  bonds: (michem.bond("a", "b"), michem.bond("b", "oxygen")),
)
#michem.render(ethanol, style: michem.style(font: "Libertinus Serif"))
```

坐标采用 x 向右、y 向上，一个单位为标准键长；全部省略时自动布局，提供时必须覆盖所有原子。
可设置电荷、同位素、附着氢数量与芳香标记。原子名称唯一、非空且不含点号。
SMILES 也可通过 `michem.smiles("CCO", positions: (...))` 指定解析顺序下的完整坐标。
手动拓扑暂不提供立体描述符接口；立体化学使用 SMILES 输入。

## CeTZ 化学流程图

```typst
#import "@preview/cetz:0.5.2": canvas, draw
#canvas({
  let style = michem.style(font: "Libertinus Serif")
  michem.cetz.molecule("CCO", at: (0, 0), name: "reactant", style: style)
  michem.cetz.molecule("CC=O", at: (5, 0), name: "product", style: style)
  michem.cetz.reaction(
    (rel: (0.3, 0), to: "reactant.east"),
    (rel: (-0.3, 0), to: "product.west"),
    above: [PCC], below: [CH₂Cl₂],
  )
})
```

分子以矢量 SVG 嵌入 CeTZ，保留 `east`、`west` 等边界锚点和 `reactant.atom-2`
这样的原子锚点。手动构图使用自定义原子名；SMILES 使用从 0 开始的解析序号。
可以配合 CeTZ 自带的曲线、箭头、分组和标注来绘制分支流程及机理。
默认 SVG 像素为 0.75pt，可通过 `scale` 或 `unit` 调整分子与锚点的共同缩放。
`examples/anchors.typ` 展示平移、旋转和等比缩放之后，原子锚点与分子图形的对应关系。

`michem.diagram(...)` 返回 SVG、尺寸、归一化原子坐标与布局诊断；
`michem.svg(...)` 返回 SVG bytes。完整接口见 [手册源码](docs/manual.typ)。

## 开发

```text
crates/michem-core/   输入模型、参数与 Chitin 适配
crates/michem-wasm/   Typst 字节协议：render / diagram
typst/               Typst 构造器、渲染与 CeTZ 接口
examples/            SMILES、手动绘制、反应流程
docs/                Typst 手册
wasm/                构建后的插件
```

联调本地 Chitin 时，可给 Cargo 传入临时 patch；无需修改公开清单：

```bash
bash scripts/build-plugin.sh \
  --config 'patch."https://github.com/chitin-dev/chitin".chitin-chem.path="../chitin/crates/chitin-chem"' \
  --config 'patch."https://github.com/chitin-dev/chitin".chitin-chemdraw.path="../chitin/crates/chitin-chemdraw"'
```

使用本地 patch 前，需要用同样的 `--config` 参数运行 `cargo generate-lockfile`，
因为 patch 会改变锁文件中的来源；完成联调后运行 `cargo generate-lockfile` 恢复 Git 来源。
Rust 格式化使用 `cargo fmt --all`；Typst 格式化可使用 `just fmt`。

## 许可

代码使用 Apache-2.0。Chitin 内置 Noto Sans 字体受 SIL OFL 1.1 许可保护，
相关声明随包保存在 `licenses/`；不改变生成化学图的许可。
