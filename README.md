# Patates

Il est peut probable que ce script puisse intéresser des non francophones, ce readme est donc en français.

Ce script permet d'obtenir des informations sur ses comptes du Crédit Agricole. Il utilise les mêmes interfaces que l'application pour smartphone « Mon Budget ». Elle nécessite un accès à la banque en ligne. Pour le moment, le script ne renvoie que du JSON. C'est juste une première étape pour aller plus loin.

## Utilisation

Il est nécessaire de créer un fichier de configuration type :

```
UserAccount=12345678901
UserCode=123456
AppCode=1234
UserEmail=Robert@Michu.fr
UserLocation=88
```

 - UserAccount : n° de compte
 - UserCode : mot de passe de la banque en ligne
 - AppCode : code de l'application Mon Budget (pour le moment, le script ne créé pas ce code)
 - UserEmail : email déclarée dans l'application Mon Budget
 - UserLocation : département de la caisse régionale

Lancement du script :

```
./patates.sh config

```

Pour le moment, le script renvoie la liste des comptes et les opérations du coompte du fichier de configuration en JSON.