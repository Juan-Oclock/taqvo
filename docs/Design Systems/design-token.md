# 🎨 Design Tokens

These tokens define the visual foundation for the app — including color palette, typography, and spacing.  
They are used by the AI coding agent (Trae AI / MCP) to ensure consistent SwiftUI code generation and theming across all screens.

---

## 🧱 **Color Palette**

| Role | Hex | Description |
|------|-----|--------------|
| **Primary Dark Background** | `#4F4F4F` | App-wide dark theme base |
| **Primary Text (Dark Mode)** | `#F6F8FA` | Main text color on dark background |
| **Primary Text (Light Mode)** | `#111111` | Main text color on white background |
| **Accent Text** | `#C5C5C5` | Secondary or muted text |
| **CTA / Highlight** | `#A8FF60` | Key action, active states, progress |

---

## ✍️ **Typography**

- **Primary Font:** Helvetica Neue  
- **Weights:** Regular / Medium / Bold  
- **Font Sizes:**  
  - Title → 24 pt  
  - Subtitle → 18 pt  
  - Body → 14 pt  
  - Caption → 12 pt  

---

## 📏 **Spacing & Radius**

| Token | Value |
|--------|--------|
| small | 8 px |
| medium | 16 px |
| large | 24 px |
| xlarge | 32 px |
| radius-small | 8 px |
| radius-medium | 16 px |
| radius-large | 24 px |

---

## 🧩 **Machine-Readable JSON**

The following JSON block is what Trae AI will parse as structured context.  
Keep this in sync if you update any values above.

```json
{
  "color": {
    "background": {
      "primaryDark": {
        "value": "#4F4F4F",
        "type": "color",
        "description": "App-wide dark theme base"
      }
    },
    "text": {
      "primaryDark": {
        "value": "#F6F8FA",
        "type": "color",
        "description": "Main text color on dark background"
      },
      "primaryLight": {
        "value": "#111111",
        "type": "color",
        "description": "Main text color on white background"
      },
      "accent": {
        "value": "#C5C5C5",
        "type": "color",
        "description": "Secondary or muted text"
      }
    },
    "cta": {
      "highlight": {
        "value": "#A8FF60",
        "type": "color",
        "description": "Key action, active states, progress"
      }
    }
  },
  "font": {
    "family": {
      "primary": {
        "value": "Helvetica Neue",
        "type": "fontFamily"
      }
    },
    "weight": {
      "regular": { "value": 400, "type": "fontWeight" },
      "medium": { "value": 500, "type": "fontWeight" },
      "bold": { "value": 700, "type": "fontWeight" }
    },
    "size": {
      "title": {
        "value": "24pt",
        "type": "fontSize",
        "description": "Primary screen titles"
      },
      "subtitle": {
        "value": "18pt",
        "type": "fontSize",
        "description": "Subheadings and section titles"
      },
      "body": {
        "value": "14pt",
        "type": "fontSize",
        "description": "Standard paragraph text"
      },
      "caption": {
        "value": "12pt",
        "type": "fontSize",
        "description": "Secondary or fine print text"
      }
    }
  },
  "spacing": {
    "small": { "value": "8px", "type": "spacing" },
    "medium": { "value": "16px", "type": "spacing" },
    "large": { "value": "24px", "type": "spacing" },
    "xlarge": { "value": "32px", "type": "spacing" }
  },
  "radius": {
    "small": { "value": "8px", "type": "borderRadius" },
    "medium": { "value": "16px", "type": "borderRadius" },
    "large": { "value": "24px", "type": "borderRadius" }
  }
}d