# stop script on error signal
set -e

# set your domain / project root directory
domain=domain.com

# set the Deployment Trigger URL that is generated and presented to you by Laravel Forge
TRIGGER_URL=https://forge.laravel.com/servers/xxxxxx/sites/xxxxx/deploy/http?token=xxxxxxx

# this is the location and name of the lock file (should be available to access from any user, therefore, /tmp works just fine)
LOCK_FILE=/tmp/deploy.lock

# check if lock file exist
if [ -f "$LOCK_FILE" ]; then
   # Send message and exit
   echo "$domain - Already running script. Will try again after 3 minutes."
   sleep 3m
   curl -I $TRIGGER_URL
   exit 0
fi
exec 99>"$LOCK_FILE"
flock -n 99


# remove old deployment folders
rm -R --force ~/deploy_"$domain"
rm -R --force ~/backup_"$domain"

cp -R ~/$domain ~/deploy_"$domain"

# Update
cd ~/deploy_"$domain"
git stash --include-untracked
git pull origin release/testing
git stash clear
composer install --no-interaction --prefer-dist --optimize-autoloader
if [ -f artisan ]; then
   php artisan migrate --force
fi
yarn install
yarn prod

# Switch (downtime for microseconds)
mv ~/$domain ~/backup_"$domain"
mv ~/deploy_"$domain" ~/$domain
if [ -d ~/"$domain"_uploads ]; then
   mkdir ~/"$domain"_uploads
fi
cd ~/$domain/public
ln -nfs ../../"$domain"_uploads ./uploads

# Delete map files in case you generate those to upload to rollbar or so
rm -rf ./**/*.map

# Restart PHP services
sudo -S service php7.4-fpm reload

# Reset opcache
echo "<?php opcache_reset(); echo 'opcache reset' . PHP_EOL; ?>" > ~/$domain/public/opcachereset.php
curl https://$domain/opcachereset.php
rm ~/$domain/public/opcachereset.php

# clean-up before exit
rm "$LOCK_FILE"
