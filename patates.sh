#!/bin/bash
#set -v

Config=$1
if [ ! -r $Config ]
then
    echo "Impossible de lire le fichier de config $Config"
    exit 1
fi
UserCodeLength=6
AppCodeLength=4
Grid=grid   # jpeg grid
UrlBase='https://ibudget.iphone.credit-agricole.fr/budget/iphoneservice'
UserAgent='MonBudget/2.0.2'
Header='X-Credit-Agricole-Device: innotek GmbH VirtualBox/Android/4.3'
ApiVersion=4

function getFromIni {
    grep $1 $Config | cut -d'=' -f 2
}

function getLocation {
    # Permet de récupérer le crId en fonction du département
    curl --silent \
        --user-agent "$UserAgent" \
        --header 'Accept: application/json' \
        $UrlBase/geoLocation/cr?q=$1 | cut -d',' -f2 | cut -d'"' -f 4
}

function getGrid {
    # Récupération de l'image du pavé numérique
    rm $Grid* 2>/dev/null

    # ATTENTION, ce cookie est nécessaire partout !
    # pas si sûr…
    curl --silent \
        --cookie-jar cookies \
        --user-agent "$UserAgent" \
        --header "$Header" \
        $UrlBase/authentication/grid > $Grid

    cookie=$(awk '/budget/ {print $6"="$7}' cookies)
    rm cookies
}

function gridToImages {
    # Découpage de l'image pour extraire chaque chiffre dans une image
    convert $Grid -crop 32x32+16+16 ${Grid}01.jpg
    convert $Grid -crop 32x32+70+16 ${Grid}02.jpg
    convert $Grid -crop 32x32+126+16 ${Grid}03.jpg
    convert $Grid -crop 32x32+182+16 ${Grid}04.jpg
    convert $Grid -crop 32x32+238+16 ${Grid}05.jpg
    convert $Grid -crop 32x32+16+72 ${Grid}06.jpg
    convert $Grid -crop 32x32+70+72 ${Grid}07.jpg
    convert $Grid -crop 32x32+126+72 ${Grid}08.jpg
    convert $Grid -crop 32x32+182+72 ${Grid}09.jpg
    convert $Grid -crop 32x32+238+72 ${Grid}10.jpg
    convert $Grid*.jpg +append new${Grid}.jpg
}

function gridToText {
    # gridTextExpanded : chaque indice du tableau contient un chiffre de la grille
    # gridText c'est la chaine de caractère correspond au pavé numérique
    gridText=$(gocr new$Grid.jpg)
    gridTextExpanded=()
    gridAccountCode=()


    for i in $(seq 0 9)
    do
        gridTextExpanded[${gridText:$i:1}]=$i
    done
    unset i
}

function createAccountCode {

    # On déduit la combinaison 
    # Si le pavé reçu est 0987654321
    # Le code utilisateur est 123456
    # On envoie 987653
    # 9 : indice de la valeur 1 dans le tableau gridTextExpanded (le pavé numérique reçu)
    # 8 : indice de la valeur 2 dans gridTextExpanded
    # etc.
    local i
    for i in $(seq 0 $(( $UserCodeLength -1 )) )
    do
        AccountCode="$AccountCode${gridTextExpanded[${UserCode:$i:1}]}"
    done
    echo $AccountCode
}

# Requête d'authentification par PUT
function putProfile {

    # authentification
    #echo "DEBUG: authentification"
    curl --silent \
        --user-agent "$UserAgent" \
        --header "$Header" \
        --cookie $cookie \
        --request PUT \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --write-out '%{http_code}' \
        --data "{\"accountCode\":\"$AccountCode\",\"accountNumber\":\"$UserAccount\",\"crId\":\"$crId\",\"exportEmail\":\"$UserEmail\",\"login\":\"$UserEmail\",\"password\":\"$AppCode\"}" \
        "$UrlBase/configuration/profiles?version=$ApiVersion" | cut -d',' -f1 | cut -d':' -f2 | sed s/\"//g
}

function authentication {
    getGrid
    gridToImages
    gridToText
    AccountCode=$(createAccountCode)
    [ $DEBUG ] && echo AccountCode: $AccountCode
    #putProfile
    UserId=$(putProfile)
    echo UserId: $UserId
    #[ $DEBUG ] && echo UserId: $UserId

}


userId=1682095
login='sylvain@collilieux.net'
partnerId="1682095-35231343000-836"
crId=836
password=5678

# Information du profil
function getProfile {
    curl \
        --user "$UserEmail:$appCode" \
        --user-agent "$UserAgent" \
        --header "$Header" \
        --request GET \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --write-out '%{http_code}' \
        --referer "$UrlBase/configuration/profiles?version=$ApiVersion" \
        "$UrlBase/configuration/profiles/${userId}/"
}

function getCrAbout {
    curl \
        --user "$HttpUserAndPassword" \
        --user-agent "$UserAgent" \
        --header "$Header" \
        --cookie $cookie \
        --request GET \
        --write-out '%{http_code}' \
        "$UrlBase/about?crId=${cdId}"
}

function getAccounts {
    curl \
        --cookie "$cookie" \
        --user "$HttpUserAndPassword" \
        --user-agent "$UserAgent" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "$Header" \
        --request GET \
        --write-out '%{http_code}' \
        $UrlBase/portfolio/${UserId}/accounts/${crId}?version=$ApiVersion

        echo "$UserEmail:$UserCode" \
        echo $UrlBase/portfolio/${UserId}/accounts/${crId}?version=$ApiVersion
}

function getBalanceHistory {
    curl \
        --cookie "$cookie" \
        --user "$HttpUserAndPassword" \
        --user-agent "$UserAgent" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "$Header" \
        --request GET \
        --write-out '%{http_code}' \
        "$UrlBase/portfolio/$userId/accounts/$crId/balanceHistory?version=$ApiVersion"
}

function getOperations {
    curl \
        --cookie "$cookie" \
        --user "$HttpUserAndPassword" \
        --user-agent "$UserAgent" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "$Header" \
        --request GET \
        --write-out '%{http_code}' \
        "$UrlBase/portfolio/$userId/accounts/$crId/$1/operations?&version=$ApiVersion"
}

[ $DEBUG ] && echo Bonjour patates

[ $DEBUG ] && echo Tous les getFromIni
UserCode=$(getFromIni UserCode)
AppCode=$(getFromIni AppCode)
UserAccount=$(getFromIni UserAccount)
UserEmail=$(getFromIni UserEmail)
UserLocation=$(getFromIni Location)

if [ ${#UserCode} -ne $UserCodeLength ]
then
    echo "Le code du compte est de ${#UserCode} chiffres au lieu de $UserCodeLength !"
    exit 1
fi

if [ ${#AppCode} -ne $AppCodeLength ]
then
    echo "Le code de l'appplication est de ${#AppCode} chiffres au lieu de $AppCodeLength !"
    exit 1
fi

crId=$(getLocation $UserLocation)
[ $DEBUG ] && echo crId: $crId

authentication
[ $DEBUG ] && echo UserId: $UserId

HttpUserAndPassword="$UserEmail:$AppCode"

getAccounts
getOperations $UserAccount

