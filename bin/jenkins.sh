#!/bin/sh
# This script makes sure that Jenkins can properly run your tests against your
# codebase.
set -e

DB_HOST="localhost"
DB_USER="hudson"

cd $WORKSPACE
VENV=$WORKSPACE/venv

echo "Starting build on executor $EXECUTOR_NUMBER..."

# Make sure there's no old pyc files around.
find . -name '*.pyc' -exec rm {} \;

if [ ! -d "$VENV/bin" ]; then
  echo "No virtualenv found.  Making one..."
  virtualenv $VENV --no-site-packages
  source $VENV/bin/activate
  pip install --upgrade pip
  pip install coverage
fi

git submodule sync -q
git submodule update --init --recursive

if [ ! -d "$WORKSPACE/vendor" ]; then
    echo "No /vendor... crap."
    exit 1
fi

source $VENV/bin/activate
pip install -q -r requirements/compiled.txt
pip install -q -r requirements/dev.txt

cp crashstats/settings/local.py-dist crashstats/settings/local.py
echo "# enabled by force by jenkins.sh" >> crashstats/settings/local.py
echo "COMPRESS_OFFLINE = True" >> crashstats/settings/local.py

echo "Starting tests..."
./manage.py collectstatic --noinput
# even though COMPRESS_OFFLINE=True is in before the tests are run 
# COMPRESS becomes (not DEBUG) which will become False so that's why we need
# to use --force here.
./manage.py compress_jingo --force
coverage run manage.py test --noinput --with-xunit
coverage xml $(find crashstats lib -name '*.py')

echo "FIN"
