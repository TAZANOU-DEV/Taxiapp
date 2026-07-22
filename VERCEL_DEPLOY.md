# Déploiement Vercel pour TaxiApp

Ce dépôt contient un backend Node.js/Express dans `Backend/` et un front-end Flutter séparé.

## Configuration Vercel

Le fichier `vercel.json` à la racine indique à Vercel :

- utiliser `Backend/server.js` comme point d'entrée Node.js
- faire correspondre les requêtes `/api/...` vers ce backend
- installer les dépendances dans `Backend`

```json
{
  "version": 2,
  "builds": [
    {
      "src": "Backend/server.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "Backend/server.js"
    }
  ],
  "installCommand": "cd Backend && npm install"
}
```

## Points importants

- Toutes les API Express sont déjà montées sous `/api/...`.
- Dans Vercel, appelez votre backend avec des URLs comme `https://<votre-projet>.vercel.app/api/auth`.
- Vercel est adapté pour les fonctions Node.js, mais pas pour des connexions Socket.IO persistantes en temps réel.

## Alternative recommandée pour Socket.IO

Si vous avez besoin de vraie communication temps réel, utilisez un hébergement avec serveur toujours actif (Render, Heroku, Railway, une VM) et conservez Vercel pour le frontend ou le routage. 
