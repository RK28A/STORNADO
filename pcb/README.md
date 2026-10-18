# pcb/

Notes PCB pour la **variante C** (carte M.2 2280 custom). À n'entamer qu'après
validation des variantes A/B (namespace monté + aller-retour fichier OK).

Points à traiter (cf. `docs/phase1-architecture.md`) :
- Empilage et plans de référence ; impédances différentielles PCIe (85 Ω) selon spec.
- Placement transceivers, longueurs/skews appariés, retour de courant.
- Rails FPGA (3,3 → 1,0/1,8 V), séquencement d'alimentation, découplage.
- Connector edge M.2 M-key, protections ESD, convection/dissipateur.
- Règles du fabricant FPGA **et** du fabricant PCB (distinguer des règles générales).

Aucun Gerber n'est fourni (règle PARTIE L : ne rien inventer). KiCad recommandé.
