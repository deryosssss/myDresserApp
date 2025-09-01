# 👗 MyDresser — AI-Powered Digital Wardrobe  

An iOS application that helps users **digitize, organize, and style their wardrobe**.  
It combines **Firebase backend services**, **AI-based tagging**, and **personalized outfit recommendations** to deliver a seamless, intelligent wardrobe experience.  

---

## 📖 Features  

- **Wardrobe Management**  
  - Add clothing items via **camera, photo library, or in-app web capture**.  
  - Auto-tag garments with category, subcategory, colours, and styles using the **Lykdat API**.  
  - Edit, favorite, delete, and filter wardrobe items.  

- **Outfit Recommendations**  
  - **Manual Outfit Builder**: Mix and match wardrobe items with optional randomization/locking.  
  - **Prompt-Based Suggestions**: Enter free text prompts (e.g., “smart casual with boots”) parsed into structured constraints.  
  - **Weather-Based Suggestions**: Integrates the **WeatherWear API** for seasonally and weather-appropriate outfits.  
  - **Dress Code Outfits**: Generate outfits strictly by “Casual”, “Smart Casual”, or “Smart” codes.  

- **Analytics & Stats**  
  - Track outfit frequency, favorites, and wardrobe usage diversity.  
  - Explore insights via interactive charts.  

- **Storage & Sync**  
  - Firebase Authentication for secure sign-in.  
  - Firebase Firestore for structured wardrobe & outfit data.  
  - Firebase Storage for image upload (with automatic compression < 10MB).  

---

## 🏗 Architecture  

The app follows a **layered architecture**:  

- **Presentation Layer**: SwiftUI views (wardrobe grid, add item, prompt screen, outfit cards, stats).  
- **Application Layer**: ViewModels + services (outfit engines, tagging, filtering, listeners).  
- **Data Layer**: Firebase Firestore, Firebase Storage, and AI API clients.  

Key design principles:  
- **MVVM pattern** for testability and clear separation of concerns.  
- **Deterministic matching engine** (fast, explainable, no recurring API cost).  
- **Abstraction boundaries** for external services (e.g., `LykdatClient`, `WardrobeFirestoreService`).  

---

## ⚙️ Technologies  

- **Swift 5 / SwiftUI** — native iOS development  
- **Firebase (Auth, Firestore, Storage)** — backend & storage  
- **Lykdat API** — clothing detection and deep tagging  
- **WeatherWear API** — weather-aware outfit suggestions  
- **Remove.bg API (optional)** — background removal for uploaded images  
- **Xcode 16 / iOS 18.5** — development & testing environment  

---

## 📂 Key Components  

- `WardrobeFirestoreService.swift` → Firestore CRUD for wardrobe items  
- `WardrobeStore.swift` → Uploads images to Firebase Storage + saves items  
- `WardrobeViewModel.swift` → Manages wardrobe state, outfits, filters  
- `LykdatClient.swift` → Client for Lykdat AI tagging API  
- `ImageTaggingViewModel.swift` → Auto-tagging & metadata editing  
- `PromptParser.swift` / `OutfitEngine.swift` → Deterministic prompt → outfit pipeline  
- `WeatherSuggestionViewModel.swift` → Weather-aware outfit suggestions  
- `DressCodeOutfitsViewModel.swift` → Dress-code constrained outfit cards  
- `ManualSuggestionViewModel.swift` → Manual outfit builder with locking & randomization  
- `AddViewController.swift` / `CropperViewModel.swift` → Camera, library, web cropper UI  
- `ColorLexicon.swift` / `SubtypeLexicon.swift` → Normalization of messy labels  

---

## 🚀 Getting Started  

### Prerequisites  
- macOS Sequoia (or later)  
- Xcode 16 (or later)  
- CocoaPods / Swift Package Manager dependencies installed  
- Firebase project configured with:  
  - **Authentication** (Email/Password enabled)  
  - **Firestore Database** (in test or production mode)  
  - **Firebase Storage** (bucket enabled)  

### Setup  
1. Clone the repo:  
   ```bash
   git clone https://github.com/<your-username>/myFinalProject.git
   cd myFinalProject

This project is for academic/research purposes. External APIs (Lykdat, WeatherWear, Remove.bg) may require commercial licensing for production use.
