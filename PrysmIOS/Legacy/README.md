# Legacy Preferences System

Ce dossier contient l'ancien système de préférences de PrysmIOS qui a été remplacé par une nouvelle implémentation moderne.

## Fichiers déplacés

- `NewsSubjectsView.swift` - Ancienne vue de sélection des sujets d'actualités
- `ResearchTopicsView.swift` - Ancienne vue de sélection des sujets de recherche  
- `UpdateFrequencyView.swift` - Ancienne vue de configuration de la fréquence de mise à jour

## Nouveau système

Le nouveau système de préférences se trouve dans `PreferencesView.swift` et offre :

### ✨ Améliorations

1. **Interface moderne** - Design step-by-step avec barre de progression
2. **UX simplifiée** - Navigation fluide entre les étapes
3. **Code plus maintenable** - Structure modulaire et réutilisable
4. **Meilleure organisation** - Séparation claire des responsabilités

### 🔄 Fonctionnalités

- **Étape 1** : Sélection des catégories d'intérêt
- **Étape 2** : Affinement avec sous-catégories
- **Étape 3** : Personnalisation (sujets custom, langue)
- **Étape 4** : Paramètres finaux (pays, fréquence, niveau de détail)

### 🎨 Design

- Cards interactives pour les catégories
- Chips pour les sous-catégories
- Animations fluides entre les étapes
- Styles de boutons cohérents
- Support du mode sombre/clair

## Migration

L'ancien système complexe avec :
- Grilles dynamiques
- API calls pour les sous-thèmes
- Trackers structurés
- Navigation complexe

A été remplacé par un système plus simple et intuitif qui se concentre sur l'essentiel : permettre à l'utilisateur de configurer ses préférences d'actualités rapidement et facilement.

## Compatibilité

Le nouveau système est compatible avec l'API backend existante et utilise les mêmes endpoints pour sauvegarder les préférences utilisateur. 