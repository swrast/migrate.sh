#!/bin/sh
# migrate.sh - very simple database migration tool

# Copyright (C) 2023 Nikita Nikiforov

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

CGREEN="\e[32m"
CRED="\e[31m"
CYELLOW="\e[33m"
CRESET="\e[0m"

usage() {
        cat << EOF
usage: $0 [-pu] [command] [file ...]

parameters:
        -p      use postgresql (requires psql)
        -u      database connection uri

commands:
        up      migrations up
        down    migrations down

migration file example:
        --- up
        CREATE TABLE users (id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL);

        --- down
        DROP TABLE users;
EOF

        exit 1
}

postgres_execute() {
        psql -v ON_ERROR_STOP=1 "$1" << EOF
$2
EOF
        exit $?
}

main() {
        while getopts ":pu:" opt; do
                case $opt in
                        u)
                                database_uri="$OPTARG"
                                ;;
                        p)
                                db_command=postgres_execute
                                ;;
                        \?)
                                usage

                                exit $?
                                ;;
                esac
        done

        shift $((OPTIND-1))

        case $1 in
                up)
                        command="up"
                        ;;
                down)
                        command="down"
                        ;;
                *)
                        usage

                        exit $?
                        ;;
        esac

        shift

        for x in $(find $@ -type f | sort); do
                script=""

                echo -n $x

                mode="none"

                while IFS= read line; do
                        case "$line" in
                                "--- up")
                                        mode="up"
                                        ;;
                                "--- down")
                                        mode="down"
                                        ;;
                                *)
                                        if [ "$command" = "$mode" ]; then
                                                script="$(printf "%s\n%s" "$script" "$line")"
                                        fi
                                        ;;
                        esac
                done < $x

                if [ -z "$script" ]; then
                        echo -e "$CYELLOW WARNING$CRESET: migration is empty, nothing to execute"

                        continue
                fi

                if ! output=$(($db_command "$database_uri" "$script") 2>&1); then
                        echo -e "$CRED FAIL$CRESET"
                        echo "$output"

                        continue
                fi

                echo -e "$CGREEN DONE$CRESET"
        done
}

main "$@"

exit $?
