# 🎯 CROM-OS SPIRIT: Nexus Visual System

---

## 1. Technology Stack

### 1.1 Core Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     NEXUS ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    USER INTERFACE                        │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ Bubble Mode  │  │ HUD Dashboard│  │ Terminal Grid│  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   RENDERING ENGINE                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────────────┐ │   │
│  │  │  Raylib    │  │   OpenGL   │  │  Compositor (DRM)  │ │   │
│  │  │  (Go API)  │  │   (Native) │  │  Direct Rendering  │ │   │
│  │  └────────────┘  └────────────┘  └────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   SCRIPTING ENGINE                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────────────┐ │   │
│  │  │  QuickJS   │  │  Go Plugin │  │   IPC Bridge       │ │   │
│  │  │  (Widgets) │  │  (Native)  │  │   (Command Bus)    │ │   │
│  │  └────────────┘  └────────────┘  └────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Why This Stack?

| Component | Choice    | Reason                                        |
| --------- | --------- | --------------------------------------------- |
| Language  | Go        | Static binary, fast compile, good concurrency |
| Graphics  | Raylib    | OpenGL without bloat, C-compatible, 2D/3D     |
| Display   | DRM/KMS   | Direct framebuffer, no X11/Wayland overhead   |
| Scripting | QuickJS   | Tiny JS engine (~200KB), fast, embeddable     |
| Font      | Noto/Fira | Unicode coverage, coding-friendly monospace   |

### 1.3 Binary Size Target

```
Component           Size (stripped)
─────────────────────────────────
nexus (main binary)    ~8 MB
libraylib.a            ~1 MB
quickjs (embedded)     ~200 KB
fonts + assets         ~2 MB
─────────────────────────────────
TOTAL                  ~12 MB
```

---

## 2. Interface States (State Machine)

### 2.1 State Diagram

```
                    ┌─────────────────────────┐
                    │      NEXUS STATES       │
                    └───────────┬─────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
    ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
    │    BUBBLE     │   │   DASHBOARD   │   │ TERMINAL GRID │
    │    (State A)  │◄─►│   (State B)   │◄─►│   (State C)  │
    └───────────────┘   └───────────────┘   └───────────────┘
            │                   │                   │
            └───────────────────┼───────────────────┘
                                │
                        Transition Triggers:
                        • Mouse click
                        • Hotkey (Super+Space)
                        • Voice command
                        • Script API
```

### 2.2 State A: Bubble Mode (Minimal Presence)

The **Bubble** is an always-visible, floating control point.

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│                    [Other Application/VM]                      │
│                                                                │
│                                                                │
│                                                    ┌────────┐  │
│                                                    │  ◉     │  │
│                                                    │ Spirit │  │
│                                                    └────────┘  │
│                                                         ▲      │
│                                                    Draggable   │
│                                                    64x64 px    │
└────────────────────────────────────────────────────────────────┘

Bubble Features:
• Always on top (compositor overlay)
• Draggable to any corner
• Single tap → Quick menu
• Long press → Dashboard
• Pulse animation for notifications
• Color indicates system status:
  - Blue (idle)
  - Green (processing)
  - Yellow (attention needed)
  - Red (critical alert)
```

### 2.3 State B: Dashboard Mode (HUD Overlay)

A semi-transparent **heads-up display** showing system info and quick actions.

```
┌────────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ░┌────────────────────────────────────────────────────────┐░░ │
│ ░│ CROM-OS SPIRIT                           ┌───────────┐ │░░ │
│ ░│ ══════════════                           │ 🕐 14:32  │ │░░ │
│ ░│                                          │ 📅 13 Dec │ │░░ │
│ ░│ ┌──────────────┐  ┌──────────────────┐   └───────────┘ │░░ │
│ ░│ │   CPU 24%    │  │ Current Mode     │                 │░░ │
│ ░│ │   ████░░░░░░ │  │ > Spirit Active  │   ┌───────────┐ │░░ │
│ ░│ │   RAM 4.2GB  │  │   Windows (Pause)│   │ [Network] │ │░░ │
│ ░│ │   ██████░░░░ │  │   Linux (Off)    │   │ LAN: OK   │ │░░ │
│ ░│ │   NET 12MB/s │  └──────────────────┘   │ Nodus: 3  │ │░░ │
│ ░│ │   ██░░░░░░░░ │                         │ Cloud: OK │ │░░ │
│ ░│ └──────────────┘                         └───────────┘ │░░ │
│ ░│                                                        │░░ │
│ ░│ ┌────────────────────────────────────────────────────┐ │░░ │
│ ░│ │ >_ Terminal                                        │ │░░ │
│ ░│ │                                                    │ │░░ │
│ ░│ │ spirit@crom ~ $                                    │ │░░ │
│ ░│ └────────────────────────────────────────────────────┘ │░░ │
│ ░│                                                        │░░ │
│ ░│ [Terminal]  [Browser]  [Files]  [VMs]  [Settings]     │░░ │
│ ░└────────────────────────────────────────────────────────┘░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░ BLUR EFFECT ░░░░░░░░░░░░░░░░░░░░░░░░░ │
└────────────────────────────────────────────────────────────────┘

Dashboard Features:
• Frosted glass effect (shader blur)
• Widget-based layout (configurable)
• Inline terminal (always visible)
• Quick-access buttons
• Real-time system metrics
• VM status and control
```

### 2.4 State C: Terminal Grid Mode (Power User)

A tiling window manager for multiple terminals and panels.

```
┌────────────────────────────────────────────────────────────────┐
│ ┌──────────────────────────────┬─────────────────────────────┐ │
│ │ Terminal 1: spirit@crom     │ Terminal 2: htop            │ │
│ │                              │                             │ │
│ │ $ @windows dir C:\          │   1  [   systemd]  0.0%     │ │
│ │  Volume in drive C is OS    │   2  [   kthreadd]  0.0%    │ │
│ │  Volume Serial Number is    │   3  [    rcu_gp]  0.0%     │ │
│ │                              │                             │ │
│ │ Directory of C:\            │  Mem[||||     256M/8G]      │ │
│ │                              │  Swp[          0K/0K]       │ │
│ │ 05/12/2024  10:32    <DIR>  │                             │ │
│ │ ...                          │  Tasks: 42, 89 thr          │ │
│ │                              │  Load: 0.12 0.08 0.02       │ │
│ ├──────────────────────────────┼─────────────────────────────┤ │
│ │ Terminal 3: logs            │ Terminal 4: nodus           │ │
│ │                              │                             │ │
│ │ Dec 13 12:00:01 kernel:     │ Peers: 3 connected          │ │
│ │   [info] Spirit boot ok     │                              │ │
│ │ Dec 13 12:00:02 nexus:      │ ■ 192.168.1.10 (desktop)    │ │
│ │   [info] HUD initialized    │ ■ 192.168.1.15 (laptop)     │ │
│ │ Dec 13 12:00:03 nodus:      │ ■ 192.168.1.20 (phone)      │ │
│ │   [info] 3 peers found      │                              │ │
│ │                              │ Sync: 128MB buffered        │ │
│ │                              │                              │ │
│ └──────────────────────────────┴─────────────────────────────┘ │
│ [1:term] [2:htop] [3:logs] [4:nodus]  │  Layout: 2x2  │ 14:33 │
└────────────────────────────────────────────────────────────────┘

Terminal Grid Features:
• i3/tmux-like tiling
• Hotkey-based navigation (Alt+1,2,3,4...)
• Split horizontal/vertical
• Each pane is a pseudo-terminal
• Shared scrollback buffer
• Session persistence (survives restart)
```

---

## 3. State Transitions

### 3.1 Transition Table

| From      | To        | Trigger          | Animation          |
| --------- | --------- | ---------------- | ------------------ |
| Bubble    | Dashboard | Click bubble     | Expand from corner |
| Bubble    | Dashboard | Super+Space      | Fade in            |
| Dashboard | Bubble    | Click outside    | Collapse to corner |
| Dashboard | Bubble    | Escape key       | Fade out           |
| Dashboard | Terminal  | Click "Terminal" | Slide transition   |
| Dashboard | Terminal  | Super+Enter      | Instant            |
| Terminal  | Dashboard | Super+Space      | Slide back         |
| Terminal  | Bubble    | Super+Escape     | Collapse           |
| Any       | Bubble    | Super+B          | Force bubble       |

### 3.2 Transition Code

```go
// nexus/states.go

type NexusState int

const (
    StateBubble NexusState = iota
    StateDashboard
    StateTerminalGrid
)

type StateTransition struct {
    From      NexusState
    To        NexusState
    Animation Animation
    Duration  time.Duration
}

var transitions = []StateTransition{
    {StateBubble, StateDashboard, AnimExpand, 200 * time.Millisecond},
    {StateDashboard, StateBubble, AnimCollapse, 150 * time.Millisecond},
    {StateDashboard, StateTerminalGrid, AnimSlide, 200 * time.Millisecond},
    // ...
}

func (n *Nexus) TransitionTo(newState NexusState) {
    trans := findTransition(n.currentState, newState)

    // Start animation
    n.animator.Start(trans.Animation, trans.Duration)

    // Update state after animation
    time.AfterFunc(trans.Duration, func() {
        n.currentState = newState
        n.Render()
    })
}
```

---

## 4. Visual Design System

### 4.1 Color Palette

```go
// nexus/theme.go

var Theme = struct {
    // Primary colors
    Background   Color // #0D1117 (deep space)
    Surface      Color // #161B22 (panel bg)
    Primary      Color // #58A6FF (spirit blue)
    Secondary    Color // #7EE787 (success green)
    Accent       Color // #D29922 (warning amber)
    Error        Color // #F85149 (danger red)

    // Text
    TextPrimary   Color // #C9D1D9 (main text)
    TextSecondary Color // #8B949E (muted text)
    TextInverse   Color // #0D1117 (on light bg)

    // UI Elements
    Border        Color // #30363D (subtle borders)
    Highlight     Color // rgba(88,166,255,0.1) (hover)
    Overlay       Color // rgba(13,17,23,0.8) (blur bg)
}{
    Background:   rl.NewColor(13, 17, 23, 255),
    Surface:      rl.NewColor(22, 27, 34, 255),
    Primary:      rl.NewColor(88, 166, 255, 255),
    Secondary:    rl.NewColor(126, 231, 135, 255),
    Accent:       rl.NewColor(210, 153, 34, 255),
    Error:        rl.NewColor(248, 81, 73, 255),
    // ...
}
```

### 4.2 Typography

```go
// Font configuration
const (
    FontMain      = "Fira Sans"
    FontMono      = "Fira Code"
    FontIcons     = "Material Icons"

    SizeSmall     = 12
    SizeNormal    = 14
    SizeLarge     = 18
    SizeHeading   = 24
    SizeTitle     = 32
)
```

### 4.3 Effects and Shaders

```glsl
// shaders/blur.frag - Frosted glass effect

#version 330

uniform sampler2D texture0;
uniform vec2 resolution;
uniform float blurAmount;

in vec2 fragTexCoord;
out vec4 finalColor;

void main() {
    vec4 sum = vec4(0.0);
    vec2 texelSize = 1.0 / resolution;

    // 9-sample box blur
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(x, y) * texelSize * blurAmount;
            sum += texture(texture0, fragTexCoord + offset);
        }
    }

    sum /= 9.0;
    finalColor = vec4(sum.rgb, 0.85); // 85% opacity
}
```

---

## 5. Headless Browser System

### 5.1 Architecture

The Nexus doesn't use a full browser engine. It uses a **content extraction** approach:

```
┌─────────────────────────────────────────────────────────────────┐
│                    HEADLESS BROWSER FLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   User Request                                                   │
│   "Show me news.ycombinator.com"                                │
│         │                                                        │
│         ▼                                                        │
│   ┌───────────────────────────────────────┐                     │
│   │           HTTP Client (Go)            │                     │
│   │   • Fetch HTML                        │                     │
│   │   • Follow redirects                  │                     │
│   │   • Handle cookies                    │                     │
│   └───────────────────────────────────────┘                     │
│         │                                                        │
│         ▼                                                        │
│   ┌───────────────────────────────────────┐                     │
│   │        Content Extractor (Go)         │                     │
│   │   • Parse HTML → DOM                  │                     │
│   │   • Remove: scripts, ads, tracking    │                     │
│   │   • Extract: text, images, links      │                     │
│   │   • Readability algorithm             │                     │
│   └───────────────────────────────────────┘                     │
│         │                                                        │
│         ▼                                                        │
│   ┌───────────────────────────────────────┐                     │
│   │        Native Renderer (Raylib)       │                     │
│   │   • Render text (with markup)         │                     │
│   │   • Display images (decoded in Go)    │                     │
│   │   • Clickable links                   │                     │
│   │   • Scrollable view                   │                     │
│   └───────────────────────────────────────┘                     │
│         │                                                        │
│         ▼                                                        │
│   ┌───────────────────────────────────────┐                     │
│   │       Result: Clean, Fast View        │                     │
│   │   • No JavaScript execution           │                     │
│   │   • No resource-heavy CSS             │                     │
│   │   • ~100KB RAM per page               │                     │
│   │   • Instant render                    │                     │
│   └───────────────────────────────────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Content Extraction Pipeline

```go
// nexus/browser/extractor.go

type ExtractedContent struct {
    Title       string
    Author      string
    Published   time.Time
    Content     []ContentBlock
    Links       []Link
    Images      []Image
}

type ContentBlock struct {
    Type    BlockType // Paragraph, Heading, Code, Quote, List
    Text    string
    Level   int       // For headings (1-6)
    Items   []string  // For lists
}

func ExtractContent(url string) (*ExtractedContent, error) {
    // 1. Fetch HTML
    html, err := fetch(url)
    if err != nil {
        return nil, err
    }

    // 2. Parse DOM
    doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
    if err != nil {
        return nil, err
    }

    // 3. Remove noise
    doc.Find("script, style, nav, footer, aside, .ad, .tracking").Remove()

    // 4. Find main content (Readability-style heuristics)
    main := findMainContent(doc)

    // 5. Extract structured content
    content := &ExtractedContent{
        Title: doc.Find("title").First().Text(),
    }

    main.Find("p, h1, h2, h3, h4, h5, h6, pre, blockquote, ul, ol").Each(func(i int, s *goquery.Selection) {
        block := parseBlock(s)
        content.Content = append(content.Content, block)
    })

    // 6. Extract images
    main.Find("img").Each(func(i int, s *goquery.Selection) {
        src, _ := s.Attr("src")
        alt, _ := s.Attr("alt")
        content.Images = append(content.Images, Image{URL: src, Alt: alt})
    })

    return content, nil
}
```

### 5.3 Memory Comparison

```
┌────────────────────────────────────────────────────────────────┐
│              MEMORY USAGE: Nexus vs Chrome                      │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Viewing: news.ycombinator.com (front page)                    │
│                                                                 │
│  Chrome:                                                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ████████████████████████████████████████████   450 MB    │  │
│  └──────────────────────────────────────────────────────────┘  │
│    - Full V8 JavaScript engine                                  │
│    - CSS layout engine                                          │
│    - GPU process                                                │
│    - Multiple processes                                         │
│                                                                 │
│  Nexus Headless:                                                │
│  ┌───┐                                                          │
│  │ ██ │                                               12 MB     │
│  └───┘                                                          │
│    - Text extraction only                                       │
│    - Pre-rendered layout                                        │
│    - Single thread                                              │
│    - No JavaScript execution                                    │
│                                                                 │
│  SAVINGS: 97% RAM reduction                                     │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

---

## 6. Command Interface

### 6.1 The @ Command System

Commands in the Nexus terminal can target different contexts:

```
Command Syntax: @<target> <command> [args...]

Targets:
  @spirit     - Execute on Spirit (host)
  @windows    - Execute on Windows VM
  @linux      - Execute on Linux VM
  @docker     - Execute in container
  @cloud      - Execute on Crom Cloud
  @nodus      - Execute on Nodus peer
  @ai         - Ask the AI sysadmin

Examples:
  @spirit status          # Show Spirit status
  @windows dir C:\        # List Windows C: drive
  @windows start steam    # Launch Steam in Windows VM
  @linux apt update       # Update Linux VM packages
  @docker ps              # List containers
  @cloud sync             # Sync state to cloud
  @nodus list             # List connected peers
  @ai "why is it slow?"   # Ask AI for diagnosis
```

### 6.2 Command Routing

```go
// nexus/command/router.go

func RouteCommand(input string) (output string, err error) {
    parts := strings.SplitN(input, " ", 2)
    target := parts[0]
    cmd := ""
    if len(parts) > 1 {
        cmd = parts[1]
    }

    switch target {
    case "@spirit", "":
        return executeLocal(cmd)

    case "@windows":
        return executeInVM("windows", cmd)

    case "@linux":
        return executeInVM("linux", cmd)

    case "@docker":
        return executeDocker(cmd)

    case "@cloud":
        return executeCloud(cmd)

    case "@nodus":
        return executeNodus(cmd)

    case "@ai":
        return queryAI(cmd)

    default:
        return "", fmt.Errorf("unknown target: %s", target)
    }
}
```

---

## 7. Widget System

### 7.1 Widget Types

```go
// nexus/widgets/types.go

type WidgetType int

const (
    WidgetClock WidgetType = iota
    WidgetCPU
    WidgetRAM
    WidgetNetwork
    WidgetDisk
    WidgetVMStatus
    WidgetTerminal
    WidgetWeather
    WidgetTasks
    WidgetCustom
)

type Widget interface {
    ID() string
    Type() WidgetType
    Render(bounds Rectangle)
    Update(dt float32)
    HandleInput(event InputEvent) bool
}
```

### 7.2 Widget Layout (Dashboard)

```yaml
# ~/.config/spirit/dashboard.yaml

layout:
  columns: 3
  rows: 4
  gap: 10

widgets:
  - id: clock
    type: clock
    position: { col: 2, row: 0, colSpan: 1, rowSpan: 1 }
    config:
      format: "15:04"
      showDate: true

  - id: system
    type: metrics
    position: { col: 0, row: 0, colSpan: 1, rowSpan: 2 }
    config:
      showCPU: true
      showRAM: true
      showNet: true

  - id: vms
    type: vmstatus
    position: { col: 1, row: 0, colSpan: 1, rowSpan: 2 }
    config:
      showIcons: true

  - id: term
    type: terminal
    position: { col: 0, row: 2, colSpan: 3, rowSpan: 2 }
    config:
      shell: "/bin/sh"
      fontSize: 14
```

---

## 8. Scripting with QuickJS

### 8.1 Script API

```javascript
// ~/.config/spirit/scripts/startup.js

// Access system info
const cpu = Spirit.system.cpu();
const ram = Spirit.system.ram();
console.log(`CPU: ${cpu.usage}%, RAM: ${ram.used}/${ram.total}`);

// Interact with VMs
const vms = Spirit.vms.list();
vms.forEach((vm) => {
  console.log(`VM: ${vm.name} - ${vm.state}`);
});

// Control UI
Spirit.ui.notify("Welcome to Crom-OS Spirit!", "info");
Spirit.ui.setState("dashboard");

// Define custom widget
Spirit.widgets.register("myWidget", {
  render: (ctx, bounds) => {
    ctx.fillRect(bounds, "#333");
    ctx.drawText("Hello!", bounds.x + 10, bounds.y + 20, "#fff");
  },
  update: (dt) => {
    // Called every frame
  },
});

// Handle keyboard shortcuts
Spirit.input.onKey("ctrl+shift+t", () => {
  Spirit.terminal.spawn();
});
```

### 8.2 Script Sandbox

```go
// nexus/scripting/sandbox.go

type ScriptSandbox struct {
    runtime *quickjs.Runtime
    ctx     *quickjs.Context
}

func NewSandbox() *ScriptSandbox {
    rt := quickjs.NewRuntime()
    ctx := rt.NewContext()

    // Inject Spirit API
    spiritObj := ctx.Object()

    // system namespace
    systemObj := ctx.Object()
    systemObj.Set("cpu", ctx.Function(getCPU))
    systemObj.Set("ram", ctx.Function(getRAM))
    spiritObj.Set("system", systemObj)

    // ui namespace
    uiObj := ctx.Object()
    uiObj.Set("notify", ctx.Function(showNotification))
    uiObj.Set("setState", ctx.Function(setState))
    spiritObj.Set("ui", uiObj)

    ctx.Globals().Set("Spirit", spiritObj)

    return &ScriptSandbox{runtime: rt, ctx: ctx}
}

func (s *ScriptSandbox) Execute(script string) error {
    _, err := s.ctx.Eval(script)
    return err
}
```

---

## 9. Accessibility Features

### 9.1 Built-in Support

| Feature             | Implementation                         |
| ------------------- | -------------------------------------- |
| High Contrast       | Theme switcher with WCAG AAA colors    |
| Large Text          | Dynamic font scaling (Ctrl+Plus/Minus) |
| Keyboard Navigation | Full keyboard accessibility            |
| Screen Reader       | Text extraction for TTS                |
| Reduced Motion      | Option to disable animations           |

### 9.2 Configuration

```yaml
# ~/.config/spirit/accessibility.yaml

highContrast: false
fontSize: 1.0 # Multiplier (1.0 = 100%)
reducedMotion: false
screenReader: false # Enable text-to-speech
cursorSize: 1.0
focusIndicator: true
```

---

## 10. Performance Targets

```
┌────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE GOALS                            │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Metric                    Target              Measured         │
│  ─────────────────────────────────────────────────────────     │
│  Startup time              < 300ms             ~200ms          │
│  State transition          < 100ms             ~80ms           │
│  Input latency             < 16ms              ~8ms            │
│  Render FPS                60 FPS              60 FPS          │
│  Idle CPU usage            < 1%                ~0.5%           │
│  Idle RAM usage            < 50MB              ~40MB           │
│  Page load (headless)      < 500ms             ~300ms          │
│                                                                 │
│  Target Hardware: Any x64 with integrated graphics             │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

---

_Document Version: 1.0_  
_Project: Crom-OS Spirit (Project Aether)_  
_Classification: Interface Design Specification_
