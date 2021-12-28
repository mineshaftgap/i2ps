#!/bin/bash

CLEANUP="true"

# establish ths directory
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)"

source /etc.defaults/VERSION

SQLITE_DB="/volume1/PlexMediaServer/AppData/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
SQLITE_BAK="$THIS_DIR/var/run/com.plexapp.plugins.library.BACKUP.db"

if [ "$majorversion" != "7" ]; then
  echo "ERROR: This has only been tested with DSM 7"
  exit 1
fi

if [ ! -f "$SQLITE_DB" ]; then
  echo "ERROR: Cannot find Plex database"
  exit 1
fi

POSSIBLE_LIB="/volume1/Media/Music"
POSSIBLE_DEF="[$POSSIBLE_LIB]"
# look for possible location
if [ -d "$POSSIBLE_LIB" ]; then
  echo -e "[$(date)] Possible music directory "$POSSIBLE_DEF" was found."
fi

# Get the new location
echo ""
read -p "Please enter location of Plex music library [$POSSIBLE_LIB]: " PLEX_LIB

if [[ -z "$PLEX_LIB" && -d "$POSSIBLE_LIB" ]]; then
  PLEX_LIB="$POSSIBLE_LIB"
fi

if [ ! -d "$PLEX_LIB" ]; then 
  echo "ERROR: Music library not found at $PLEXLIB"
  exit 1
fi

# find where the iTunes Library XML is
read -p "Please enter location of iTunes Library XML on Synology [./var/run/Library.xml]): " LIBRARY_XML
echo ""

if [ -z "$LIBRARY_XML" ]; then
  LIBRARY_XML="$THIS_DIR/var/run/Library.xml"
fi

if [ ! -e "$LIBRARY_XML" ]; then
  echo "ERROR: Cannot find $LIBRARY_XML, please double check location."
  echo "If you followed the instructions, it should be a location like $THIS_DIR/var/run/Library.xml"
  exit 1
fi

# ask for account, volunteering account_id 1
ACCOUNTS=$(
  echo 'SELECT name FROM accounts ORDER BY created_at;' |
  sqlite3 "$SQLITE_DB"|
  awk '{print FNR " " $0}'
)
POSSIBLE_ACCT=$(echo -e "$ACCOUNTS"|head -n 1)

# Get the new location
echo "$ACCOUNTS"
read -p "Please enter the number of the account who owns this Plex music library [$POSSIBLE_ACCT]: " CHOICE

if [[ -z "$ACCOUNT" ]]; then
  CHOICE=1
fi

ACCOUNT=$(echo "$ACCOUNTS"|awk -v CHOICE=${CHOICE} '$1 == CHOICE {print $2}')

echo ""
echo "[$(date)] Using account $ACCOUNT"

echo "[$(date)] Backing up $SQLITE_DB to $SQLITE_BAK"
cp "$SQLITE_DB" "$SQLITE_BAK"

echo "[$(date)] Found $LIBRARY_XML"
LIBRARY_JSON="$THIS_DIR/var/run/Library.json"

# determine cpu arch
case $(uname -m) in
  i386 | i686 | x86_64) ARCH="intel" ;;
  arm | arm64)          ARCH="arm"   ;;
esac

PLIST2JSON="$THIS_DIR/plist2json/plist2json-linux-$ARCH"

echo "[$(date)] Discovered CPU architecture as $ARCH based CPU, will use $PLIST2JSON"

echo "[$(date)] Converting $LIBRARY_XML to JSON for earier manipulation"
$PLIST2JSON "$LIBRARY_XML" > "$LIBRARY_JSON"

# Get the Music Folder
ORIG_LIB="$(jq -r '."Music Folder"' "$LIBRARY_JSON")"

echo "[$(date)] Found original music folder is $ORIG_LIB"

META_CSV="$THIS_DIR/var/run/track-meta.csv"
echo "[$(date)] Extracting location, play count, rating and skip count"
# grab meta data, replace iTunes location with Plex, urldecode
cat var/run/Library.json |
  jq -r '
    .Tracks[]|
    select(
      (.Kind|contains("audio")) and
      (has("Location"))         and 
      (
        .Rating       != null or
        ."Play Count" != null or
        ."Skip Count" != null
      )
    )|
    [
      .Location,
      (if .Rating == null then null else (.Rating / 10.0) end),
      ."Play Count",
      ."Play Date UTC",
      ."Date Added",
      ."Date Modified",
      ."Skip Count",
      ."Skip Date",
      ."Date Modified"
    ]|
    @csv
  ' |
  sed "s#${ORIG_LIB}Music#${PLEX_LIB}#g" |
  php -r "echo rawurldecode(file_get_contents('php://stdin'));" \
  >> $META_CSV

# import meta data into sqlite DB
echo "[$(date)] Making temp DB table with location, play count, rating and skip count"
(cat <<SQL_EOF
DROP TABLE IF EXISTS _i2ps;

CREATE TABLE IF NOT EXISTS _i2ps (
  file            varchar(255) PRIMARY KEY NOT NULL,
  rating          float,
  view_count      integer,
  last_viewed_at  datetime,
  created_at      datetime,
  updated_at      datetime,
  skip_count      integer,
  last_skipped_at datetime,
  last_rated_at   datetime
);

.mode csv
.import $META_CSV _i2ps
.mode list

UPDATE _i2ps
SET
  last_viewed_at  = datetime(last_viewed_at),
  created_at      = datetime(created_at),
  updated_at      = datetime(updated_at),
  last_skipped_at = datetime(last_skipped_at),
  last_rated_at   = datetime(last_rated_at);

DROP TABLE IF EXISTS metadata_item_settings_BACKUP;
CREATE TABLE metadata_item_settings_BACKUP AS
SELECT * FROM metadata_item_settings;

INSERT INTO metadata_item_settings
(
  account_id,
  guid,
  rating,
  view_count,
  last_viewed_at,
  created_at,
  updated_at,
  skip_count,
  last_skipped_at,
  last_rated_at
)
SELECT
  a.id account_id,
  m.guid,
  s.rating,
  s.view_count,
  s.last_viewed_at,
  s.created_at,
  s.updated_at,
  s.skip_count,
  s.last_skipped_at,
  s.last_rated_at
FROM media_items i
JOIN metadata_items m ON i.metadata_item_id = m.id
JOIN media_parts p ON i.id = p.media_item_id
JOIN accounts a ON a.name = '$ACCOUNT'
JOIN _i2ps s ON p.file = s.file
LEFT JOIN metadata_item_settings mis ON m.guid = mis.guid
WHERE mis.guid IS NULL;
SQL_EOF
) | sudo sqlite3 "$SQLITE_DB"

if [ "$CLEANUP" == "true" ]; then
  echo "[$(date)] Cleaning up"
  echo 'DROP TABLE _i2ps;' | sudo sqlite3 "$SQLITE_DB"
  rm $LIBRARY_JSON $META_CSV
fi

echo ""
echo "Your iTunes meta data has been imported into your Plex library."
echo ""
echo "In case there are any issues data has been backed up."
echo "First, the whole Plex database has been backed up to '$SQLITE_BAK'"
echo "Second, the table metadata_item_settings was backed up to the table 'metadata_item_settings_BACKUP'"
echo ""
echo "Happy listening!"
