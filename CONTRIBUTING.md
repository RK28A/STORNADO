# Contribuer à STORNADO

## Règles de qualité (reprises du cahier des charges)
1. Distinguer **spécification / hypothèse / simulation / mesure / objectif**.
2. Références réelles + versions exactes des specs (PCIe Base, NVMe 2.0c).
3. **Ne pas annoncer de compatibilité sans test.**
4. Ne jamais inventer prix, puissance ou débit.
5. Moteur DMA autorisé ≠ accès arbitraire RAM.
6. Interface PCIe ≠ contrôleur NVMe complet.
7. Tests reproductibles, modularité (logique portable vs wrappers IP).
8. Préciser outils/commandes/fichiers.
9. Une alternative par décision majeure.
10. Ne pas ignorer les contraintes M.2 (alim/place).
11. Prévoir récupération carte et erreurs de flash.
12. Vocabulaire exact — **aucune** affirmation de furtivité/indétectabilité.

## Workflow
- Branche par fonctionnalité, PR avec description claire.
- `make test-host` et `make sim` doivent passer (CI les exécute).
- Tout module RTL neuf : testbench + balise `TODO-IP`/`TODO-SPEC` si dépendant du matériel.
- Marquer explicitement ce qui est prouvé en sim vs ce qui dépend du matériel réel.
