#!/bin/bash

# Script, which allows per-user bayes db's for a dovecot virtual user
# setup. sa-learn parses a set amount of folders (.Junk.Spam and .Junk.Ham) for
# Ham/Spam and adds it to the per-user db.

MAIL_DIR=/var/mail/vhosts
SPAMASS_DIR=/var/mail/vhosts # store bayes with mail
SPAM_FOLDER=".Spam"
HAM_FOLDER=".Ham"

# get all mail accounts
for domain in $MAIL_DIR/*; do
        for user in $MAIL_DIR/${domain##*/}/*; do
                mailaccount=${user##*/}
                dbpath=$SPAMASS_DIR/${domain##*/}/$mailaccount/bayes
                spamfolder=${domain}/${mailaccount}/.maildir/$SPAM_FOLDER
                hamfolder=${domain}/${mailaccount}/.maildir/$HAM_FOLDER

                if [ -d $spamfolder ] ; then
                        [ ! -d $dbpath ] && mkdir -p ${dbpath}
                        echo "Learning Spam from ${spamfolder} for user ${mailaccount}"
                        nice sa-learn --spam --dbpath ${dbpath} --no-sync ${spamfolder}/{cur,new}
                fi

                if [ -d $hamfolder ] ; then
                        echo "Learning Ham from ${hamfolder} for user ${mailaccount}"
                        nice sa-learn --ham --dbpath ${dbpath} --no-sync ${hamfolder}/{cur,new}
                fi

                if [ -d $spamfolder -o -d $hamfolder ] ; then
                        nice sa-learn --sync --dbpath $dbpath

                        # Fix dbpath permissions
                        chown -R mail.mail ${dbpath}
                        chmod 770 ${dbpath}
                fi
        done
done
