#!/usr/bin/env bash

generate_request_body() {
  cat <<EOF
{
  "user_id": "$id",
  "email": "$email",
  "name": "$firstName $lastName",
  "custom_attributes": {
    "attribute_name": "$value"
  }
}
EOF
}

if [ $# -lt 1 ]; then
  echo "Please provide intercomAuthToken"
  exit 1
fi

DB=db
USER=db-user-name
SUFFIX=db-instance-name
HOST=db-instance-name.postgres.database.azure.com

echo "HOST: ${HOST}"
echo "DB: ${DB}"
echo "USER: ${USER}@${SUFFIX}"

(
  psql -F "|" -1 -A -t -h ${HOST} ${DB} ${USER}@${SUFFIX} <<EOF
SELECT id, email, firstName, lastName
FROM users;
EOF
) | (
  not_processed_users=""
  while IFS="|" read -r id email firstName lastName; do

    echo "from DB: id='${id}', email='${email}', firstName='${firstName}', lastName='${lastName}'"

    value="custom attribute value"
    request_body=$(generate_request_body)
    echo "request body=${request_body}"

    response=$(
      curl --write-out "%{http_code}" -k https://api.intercom.io/users -s \
        -o /dev/null \
        -H "Authorization:Bearer $1" \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -d "${request_body}"
    )
    echo "${response}"

    if [ "$response" -ne 200 ]; then
      not_processed_users="${id}\n${not_processed_users}"
    fi

  done

  echo
  echo "Not processed users:"
  echo "${not_processed_users}"
) >custom_attribute_to_intercom.log
