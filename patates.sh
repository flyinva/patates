#!/bin/bash
# (c) 2013 Flyinva - Licence WTFPL http://www.wtfpl.net/txt/copying/
# Utilisez ce script en connaissance de cause et à vos risques et périls.
# Gardez vos mots de passe sous votre contrôle.

#ALL_PROXY='http://127.0.0.1:8080'
CURL='curl --silent --cookie cookies --cookie-jar cookies -k'

UserCodeLength=6
AppCodeLength=4
Grid=/tmp/grid   # jpeg grid
UrlBase='https://ibudget.iphone.credit-agricole.fr/budget/iphoneservice'
UserAgent='MonBudget/2.0.5'
Header='X-Credit-Agricole-Device: patates/Android/4.3'
ApiVersion=4
OcrCommand=gocr

function getFromIni {
    grep $1 $Config | cut -d'=' -f 2
}

function getLocation {
    # Permet de récupérer le crId en fonction du département
    #curl --silent --cookie cookies --cookie-jar cookies -k \
    $CURL \
        --user-agent "$UserAgent" \
        --header 'Accept: application/json' \
        $UrlBase/geoLocation/cr?q=$1 | jq '.caisseRegionale[0].id | tonumber'
}

function getGrid {
    # Récupération de l'image du pavé numérique
    rm $Grid* 2>/dev/null

    # ATTENTION, ce cookie est nécessaire partout !
    #curl --silent --cookie cookies --cookie-jar cookies -k \
    $CURL \
        --user-agent "$UserAgent" \
        --header "$Header" \
        $UrlBase/authentication/grid > $Grid
}

function gridToImage {
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
    convert $Grid*.jpg +append ${Grid}new.jpg
}

function gridToText {
    # gridTextExpanded : chaque indice du tableau contient un chiffre de la grille
    # gridText c'est la chaine de caractère correspond au pavé numérique
    gridText=$($OcrCommand ${Grid}new.jpg)
    gridTextExpanded=()
    gridAccountCode=()
    
    local i
    for i in $(seq 0 9)
    do
        gridTextExpanded[${gridText:$i:1}]=$i
    done
    rm $Grid*
}

function createAccountCode {
    # Si le pavé reçu est 0987654321
    # Le code utilisateur est 123456
    # On envoie 987653
    # 9 : indice de la valeur 1 dans le tableau gridTextExpanded (le pavé numérique reçu)
    # 8 : indice de la valeur 2 dans gridTextExpanded
    # etc.
    local i
    local AccountCode
    AccountCode=''
    for i in $(seq 0 $(( $UserCodeLength -1 )) )
    do
        AccountCode="$AccountCode${gridTextExpanded[${UserCode:$i:1}]}"
    done
    echo $AccountCode
}

# Requête d'authentification avec un HTTP PUT de données JSON
# depuis la v2.0.5 de monbudget
function postAuthentication {
    
    # Il faut reprendre le cookie reçu avec l'image du pavé numérique
    $CURL \
        --user-agent "$UserAgent" \
        --header "$Header" \
        --user "$HttpUserAndPassword" \
        --request POST \
        --header 'Accept: application/json' \
        --data "bamCode=$AccountCode&login=$UserEmail&accountNumber=$UserAccount&crId=$crId" \
        "$UrlBase/authentication/strong/v1" | jq '.userid | tonumber'
}

# Requête d'authentification avec un HTTP PUT de données JSON
# ce n'est plus ce rq
function putProfile {
    
    # Il faut reprendre le cookie reçu avec l'image du pavé numérique
    $CURL \
        --user-agent "$UserAgent" \
        --header "$Header" \
        --request PUT \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --data "{\"accountCode\":\"$AccountCode\",\"accountNumber\":\"$UserAccount\",\"crId\":\"$crId\",\"exportEmail\":\"$UserEmail\",\"login\":\"$UserEmail\",\"password\":\"$AppCode\"}" \
        "$UrlBase/configuration/profiles?version=$ApiVersion" | jq '.userid | tonumber'
}

function authentication {
    getGrid
    gridToImage
    gridToText
    AccountCode=$(createAccountCode)
    [ $DEBUG ] && echo AccountCode: $AccountCode
    UserId=$(postAuthentication)
}

function getUrl {
    $CURL \
        --user "$HttpUserAndPassword" \
        --user-agent "$UserAgent" \
        --header "Accept: application/$AcceptContent" \
        --header "$Header" \
        --request GET \
        $UrlBase$1?version=$ApiVersion
}

function getCrAbout {
    getUrl "/about?crId=${cdId}"
}

function getAccounts {
    authentication
    getUrl "/portfolio/$UserId/accounts/$crId"
}

function getBalanceHistory {
    getUrl "/portfolio/$UserId/accounts/$crId/balanceHistory"
}

function getRib {
    getUrl "/portfolio/$UserId/accounts/$crId/$1/rib"
}

function getCategories {
    getUrl "/configuration/profiles/$UserId/categories"
}

function getOperations {
    getUrl "/portfolio/$UserId/accounts/$crId/$1/operations"
}

# Virement
function putTransfer {
    # nécessaire avant chaque opération
    authentication

    # Il faut reprendre le cookie reçu avec l'image du pavé numérique
    $CURL \
        --user-agent "$UserAgent" \
        --header "$Header" \
        --user "$HttpUserAndPassword" \
        --request POST \
        --header 'Accept: application/json' \
        --data "fromAccountId=$1&toAccountId=$2&amount=$3&label=$4" \
        "$UrlBase/portfolio/$UserId/operations/$crId/transfer?version=$ApiVersion" | jq '.infos[1].message'
}

Config=$1
if [ ! -r "$Config" ]
then
    echo "Impossible de lire le fichier de config $Config"
else
    [ $DEBUG ] && echo Tous les getFromIni
    UserCode=$(getFromIni UserCode)
    AppCode=$(getFromIni AppCode)
    UserAccount=$(getFromIni UserAccount)
    UserEmail=$(getFromIni UserEmail)
    UserLocation=$(getFromIni UserLocation)
    AcceptContent=$(getFromIni AcceptContent)
    AcceptContent=${AcceptContent:-json}
    HttpUserAndPassword="$UserEmail:$AppCode"

    if [ ${#UserCode} -ne $UserCodeLength ]
    then
        echo "Le code du compte est de ${#UserCode} chiffres au lieu de $UserCodeLength !"
    fi

    if [ ${#AppCode} -ne $AppCodeLength ]
    then
        echo "Le code de l'application est de ${#AppCode} chiffres au lieu de $AppCodeLength !"
    fi

    crId=$(getLocation $UserLocation)
fi

