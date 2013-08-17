# Patates

Il est peut probable que ce script puisse intéresser des non francophones, ce readme est donc en français.

Ce script permet d'obtenir des informations sur ses comptes du Crédit Agricole. Il utilise les mêmes interfaces que l'application pour smartphone « Mon Budget ». Elle nécessite un accès à la banque en ligne. Pour le moment, le script ne renvoie que du JSON ou du XML.

Merci à Valentin et Yoann pour leur aide.

## Utilisation

Il est nécessaire de créer un fichier de configuration type :

```
UserAccount=12345678901
UserCode=123456
AppCode=1234
UserEmail=Robert@Michu.fr
UserLocation=88
AcceptContent=xml
```

 - UserAccount : n° de compte
 - UserCode : mot de passe de la banque en ligne
 - AppCode : code de l'application Mon Budget (pour le moment, le script ne créé pas ce code)
 - UserEmail : email déclarée dans l'application Mon Budget
 - UserLocation : département de la caisse régionale
 - AcceptContent : on peut demander au serveur de recevoir du XML (valeur par défaut : JSON)

Lancement du script :

```
source patates.sh fichierconfig
getAccounts
getOperations
getBalanceHistory
```

Il est possible de combiner avec l'excellent [jq](http://stedolan.github.io/jq/manual).

```
getAccounts | jq ".account[] | select(.isExternal==false) | {Solde: .balance,No: .id, label: .label, Detenteur: .holder}"
getOperations 12345678901 | jq ".operation[] | select(.date > \"$(date -d'now - 5 days' +%Y%m%d)\" ) | {montant: .amount, label: .longLabel, date: .date}"

```


## Fonctionnement

### Identifiant de la caisse régionale

Il faut commencer par trouver l'identifiant de la caisse régionale en fonction du département : fonction `getLocation`.


### Pavé numérique pour l'authentification

L'application demande le mot de passe web qui permet d'accéder au site web de gestion. Un pavé numérique aléatoire sert à encoder ce mot de passe (comme avec le site web mobile).

Le serveur envoie un pavé numérique de 10 chiffres dans un ordre aléatoire (`getGrid`). Cette grille est découpée en 10 images dont on supprime le cadre qui gêne l'OCR. On assemble les 10 chiffres dans une seule image en respectant l'odre (`gridToImages`) puis on l'analyse par OCR (`gridToText`). Le script utilise [gocr](http://jocr.sourceforge.net/) mais n'importe quel OCR devrait faire l'affaire.


Exemple :
* Pavé reçu : 0987654321
* Code utilisateur : 123456
* On envoie : 987653
* 9 : indice de la valeur 1 dans le le pavé numérique
* 8 : indice de la valeur 2
* etc.



### Authentification

L'application mobile demande une adresse mail et un code à 4 chiffres censés protéger l'accès à l'application (elle stocke des données en local dans une base sqlite). Au premier envoi au serveur, le requête crée un compte avec cette adresse mail et ce code à 4 chiffres. Si on utilise la même adresse mail sur un autre appareil, il faut utiliser le même code.

L'authentification est faite par un HTTP PUT de données JSON.

```json
{
    "accountCode"   : "123456",
    "accountNumber" : "12345678901",
    "crId"          : "888",
    "exportEmail"   : "toto@titi.fr",
    "login"         : "toto@titi.fr",
    "password"      : "1234"
}
```

* accountCode : la combinaison obtenue à partir du mot de passe web et du pavé numérique envoyé par le serveur
* accountNumber : un numéro de compte valide (a priori 11 chiffres)
* crId : [identifiant de la caisse régionale][Identifiant de la caisse régionale]
* exportEmail, login : adresse mail entrée dans l'application
* password : code à 4 chiffres demandées par l'application

Après le PUT, si l'utilisateur n'existe par, il est créé. Le JSON de retour indique si l'opération s'est bien passée. Certains paramètre de ce retour sont utiles ensuite notamment le `userId` (fonction `putProfile`).

Retour suite à une création de compte : 

```json
{
    "userid"        :   "1234567",
    "partnerId"     :   "1234567-12345678901-888",
    "isNew"         :   true,
    "warnings"      :   [],
    "errors"        :   [],
    "infos"         :   [
        { "message"     :   "addProfile" },
        { "message"     :   "OK" }
    ]
}
```

Si l'utilisateur (adresse mail) existait déjà, `isNew` serait à `false`.

Il faut refaire ce PUT avant certaines opérations (liste des comptes, virement, etc.) et utiliser le cookie reçu pour continuer.


### Requêtes au serveur

Après l'authentification, l'accès aux pages nécessitent une authentification `HTTP basic`. Il faut utiliser le couple adresse mail + code à 4 chiffres. La plupart des requêtes sont des HTTP GET avec certains paramètres dans le chemin de l'URL (exemple : `/portfolio/$UserId/accounts/$crId`).

Pour certaines pages, il faut repasser par l'authentification par le pavé numérique (les virements notamment).

