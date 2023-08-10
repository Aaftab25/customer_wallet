#!/bin/bash
#First check if system has docker installed or not, and then check if required docker containers are running or not
WEBSERVER_CONTAINER='OPS-webserver'
DB_CONTAINER='OPS-database'

IS_WEBSERVER_CONTAINER_RUNNING=$(docker inspect --format="{{.State.Running}}" $WEBSERVER_CONTAINER 2> /dev/null)
IS_DB_CONTAINER_RUNNING=$(docker inspect --format="{{.State.Running}}" $DB_CONTAINER 2> /dev/null)

WEBSERVERRES=$(docker ps -a | grep "$WEBSERVER_CONTAINER" | wc -l)
DBRES=$(docker ps -a | grep "$DB_CONTAINER" | wc -l)
if [ -z "$(command -v docker)" ]
then 
    echo "$(tput setaf 1)Your system does not have docker installed, please contact System Administrator!"
    exit
else
    if [ "$IS_WEBSERVER_CONTAINER_RUNNING" = false -o "$IS_DB_CONTAINER_RUNNING" = false ]
    then
        echo "$(tput setaf 1)It seems you do not have running docker container, please start it!"
        exit
    fi
fi
#Remove the directories if it's already avilable
docker exec $WEBSERVER_CONTAINER sh -c 'rm -Rf /var/www/html/'${PWD##*/}'/public_html /var/www/html/'${PWD##*/}'/database /var/www/html/'${PWD##*/}'/tmpcache /var/www/html/'${PWD##*/}'/ops-lic'
#Default themes for development
THEME1='default'
THEME2='seablue'
THEME3='aqua'
CORPORATETHEME='corporate'
STORETHEME='store'
tput setaf 6 bold; echo "\n✨ Welcome to Onprintshop Development Setup \n"
tput sgr0

# All repository
CODEREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/opscore.git"
DATABASEREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/database.git"
THEMESREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/themes.git"
SHIPPINGREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/shippinggateways.git"
PAYMENTREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/paymentgateways.git"
THIRDPARTYREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/externalservices.git"
ASSETSREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/assets.git"
MISCREPOURL="git@rxgit.radixweb.in:rxprojects/opscore/php/misc.git"

read -p "$(tput setaf 2)?$(tput sgr0) Your database user name: " DBUSER
read -p "$(tput setaf 2)?$(tput sgr0) Your database password: " DBPASS
read -p "$(tput setaf 2)?$(tput sgr0) Your database name: " DBNAME
read -p "$(tput setaf 2)?$(tput sgr0) Do you want to copy ops crud script (yes/no)? [default = yes]: " OPSCRUD
tput setaf 6; echo "\n Please wait we are setting up things for you...\n"
tput sgr0

OPSCRUD=${OPSCRUD:-yes}

# 1. Clone Code Repository development branch
tput setaf 2;echo " 1. Setting up main code...\n"
tput sgr0
git clone -b development --single-branch $CODEREPOURL public_html
tput setaf 2;echo "\n Main code setup finished! \n"
tput sgr0

# 2. Clone Database Repository development branch
tput setaf 2;echo "\n 2. Setting up your database...\n"
tput sgr0
git clone -b development --single-branch $DATABASEREPOURL database
tput setaf 3;echo "\n Importing SQL into database, please wait..."
tput sgr0
#Import stable SQL
docker exec $WEBSERVER_CONTAINER sh -c 'mysql -hdatabase -u'$DBUSER' -p'$DBPASS' '$DBNAME' < /var/www/html/'${PWD##*/}'/database/sql/ops_db.sql'
tput setaf 2;echo "\n Database setup finished! \n"
tput sgr0

# 3. Clone the Themes Repository
tput setaf 2;echo "\n 3. Setting up your theme... \n"
tput sgr0
git clone --no-checkout --filter=blob:none $THEMESREPOURL public_html/themes/
cd public_html/themes
git config core.sparsecheckout true
printf "\n/standard/$THEME1 \n/standard/$THEME2 \n/standard/$THEME3 \n/standard/$CORPORATETHEME \n/standard/$STORETHEME \n/README.md \n"  > .git/info/sparse-checkout
git checkout master

THEMEININFILE="standard/$THEME2/theme.ini"
mkdir image_set
if [ -f "$THEMEININFILE" ]; then
    image_set=$(awk -F ":" '/Set/ {print $2}' $THEMEININFILE)    
    if [ ! -z "$image_set" ]
    then
        git config core.sparsecheckout true
        echo "assets/products/$image_set" >> .git/info/sparse-checkout
    fi
    git config core.sparsecheckout true
    echo "assets/others/$THEME2" >> .git/info/sparse-checkout
    git checkout master
    if [ ! -z "$image_set" ]
    then
        mv assets/products/$image_set/* image_set/
    fi
    mv assets/others/$THEME2/* image_set/
    rm -rf assets
fi

mv standard/$THEME1 .
mv standard/$THEME2 .
mv standard/$THEME3 .
mv standard/$CORPORATETHEME .
mv standard/$STORETHEME .
rm -rf standard/ .git/
#Update them name in table
docker exec $DB_CONTAINER  sh -c 'mysql -u'$DBUSER' -p'$DBPASS' -e "INSERT INTO site_theme (site_theme_id, theme_name, theme_dir_name, sort_order, theme_setting) VALUES (2, \"'$THEME2'\", \"'$THEME2'\", 1, \"\"), (3, \"'$THEME3'\", \"'$THEME3'\", 3, \"\");" '$DBNAME
docker exec $DB_CONTAINER  sh -c 'mysql -u'$DBUSER' -p'$DBPASS' -e "UPDATE configuration_master SET set_value = \"'$THEME2'\" WHERE constant_name = \"SITE_TEMPLATE\";" '$DBNAME
tput setaf 2;echo "\n Theme set up finished! \n"
tput sgr0

#Payment method, Shipping method, External services
tput setaf 2;echo "\n 4. Setting up third party services (Payment, Shipping and others) ... \n"
tput sgr0
# 4. Clone Shipping Repository
cd ../..
git clone --no-checkout --filter=blob:none $SHIPPINGREPOURL public_html/shipping/
cd public_html/shipping/
git config core.sparsecheckout true
printf "\n/README.md\n/fedex_12.0\n/ups_3.0\n/usps_2.0\n/weight_based\n/quantity_based\n/localpickup\n/flatship\n/shipping_cost_by_ordersubtotal\n/shipping.php"  >> .git/info/sparse-checkout
git checkout development

# 5. Clone Payment Repository
cd ../..
git clone --no-checkout --filter=blob:none $PAYMENTREPOURL public_html/payment/
cd public_html/payment/
git config core.sparsecheckout true
printf "\n/README.md\n/cheque\n/paypal_standard\n/payon_account\n/pos\n/partial_payment\n/payment.php"  >> .git/info/sparse-checkout
git checkout development

# 6. Clone External Services / Third Party Repository
cd ../..
git clone --no-checkout --filter=blob:none $THIRDPARTYREPOURL public_html/external_service
cd public_html/external_service/
git config core.sparsecheckout true
printf "\n/README.md\n/BaseService.php\n/FB\n/activecampaign\n/addshoppers\n/adobestock\n/amazon\n/autocurrencylanguage\n/avatax\n/captcha\n/clickatell\n/clippingmagic\n/depositphotos\n/dropbox\n/dropboximage\n/eddm\n/externalservice.php\n/facebook\n/facebookpixel\n/flickr\n/foreover\n/gdrive\n/gdriveimage\n/google\n/googleaddress\n/googlebusinessreview\n/googleservice\n/googletagmanager\n/gst\n/gupshupwhatsapp\n/hubspot\n/indiasms\n/instagramv2\n/install_service\n/keyinvoice\n/klaviyo\n/leaddyno\n/mailchimp\n/mailershaven\n/mailgun\n/mandrill\n/mvaayoo\n/opsmailchimpautomation\n/picasa\n/pixabay\n/portfoliosharing\n/presswise\n/printersplan\n/pushpad\n/quickbook\n/quickbookdesktop\n/quoteprintworkflow\n/reviewio\n/salesforce\n/sendinblue\n/sevenoffice\n/shipstation\n/shopvox\n/stampedio\n/taxcloud\n/taxjar\n/toplusms\n/trustpilot\n/twilio\n/twiliowhatsapp\n/uptownsms\n/usadata\n/xero\n/xerov2\n/yotpo\n/zapier-services\n/zendesk\n/zoho\n/zohobooks"  >> .git/info/sparse-checkout
git checkout development
tput setaf 2;echo "\n Third party setup finished! \n"

# 7. Clone Init Setup
echo "\n 5. Finalizing setup ...\n"
tput sgr0
cd ../..
git clone $ASSETSREPOURL init-setup
mv init-setup/README.md init-setup/images/README.md
[ -d "init-setup/opslogs" ] && mv init-setup/opslogs .
mv init-setup/* public_html/
rm -rf init-setup
cp -rpf public_html/themes/image_set/* public_html/images/
rm -rf public_html/themes/image_set

#Create Licence key
mkdir ops-lic
echo "OPSDEVELOPMENT0e52e92e889884f4af61fea42" >ops-lic/license_key.txt

#Add user database details
rm public_html/localconfig/localconfig.php
echo "<?php
        define('CONNECTION_TYPE','mysql');
        define('DATABASE_USERNAME','$DBUSER');
        define('DATABASE_PASSWORD','$DBPASS');
        define('DATABASE_NAME','$DBNAME');
        define('DATABASE_HOST','database');
        define('DATABASE_PORT','3306');
" >>public_html/localconfig/localconfig.php

LANGUAGES="spanish russian"
#Import languages
if [ "$LANGUAGES" != "" ]; then
    tput setaf 2;echo "\n 6. Adding additional languages : \"$LANGUAGES\" \n"
    tput sgr0
    git archive --format=tar --remote=$MISCREPOURL master scripts/php/import_language | tar -x
    mv scripts/php/import_language/ .
    docker exec $WEBSERVER_CONTAINER sh -c "php /var/www/html/"${PWD##*/}"/import_language/import_language_data.php '${LANGUAGES}'"
    rm -Rf scripts
    rm -Rf import_language
fi

if [ "$OPSCRUD" = yes ]; then
    git archive --format=tar --remote=$MISCREPOURL HEAD -- scripts/php/ops_crud/ops_crud.php | tar -O -xf - > public_html/admin/ops_crud.php
fi

mkdir -p tmpcache search_data/temp
chmod -R 777 tmpcache ops-lic public_html/images public_html/cache search_data
[ -d "opslogs" ] && chmod -R 777 opslogs

#install composer modules
docker exec $WEBSERVER_CONTAINER sh -c '/usr/bin/php8.1 /usr/local/bin/composer install -d /var/www/html/'${PWD##*/}'/public_html/'

# Gulp
docker exec $WEBSERVER_CONTAINER sh -c "cd /var/www/html/${PWD##*/}/public_html/ && npm install && gulp"

tput setaf 6;echo "\n🎉 You have successfully setup the project!\n"
tput sgr0
