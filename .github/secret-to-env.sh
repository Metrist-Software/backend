for s in $(aws secretsmanager get-secret-value --secret-id /prod/gh-actions/secrets | \
            jq -r '.SecretString | fromjson | to_entries | map(.key + "=" + .value) | .[]'); do
  key_val=(${s//=/ })
  echo "::add-mask::${key_val[1]}"
  echo "${key_val[0]}=${key_val[1]}" >> $GITHUB_ENV
  echo "${key_val[0]}=${key_val[1]}" >> $GITHUB_OUTPUT
done
