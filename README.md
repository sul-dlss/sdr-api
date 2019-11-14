# Repository API

This provides a deposit API for the SDR.

## Create a user

```
./bin/rails runner -e production 'User.create!(email: "jcoyne@justincoyne.com", password:  "sekret!")'
```

## Authorization

Log in to get a token by calling:

```
curl -X POST -H 'Content-Type: application/json' \
  -d '{"email":"jcoyne@justincoyne.com","password":"sekret!"}' \
  https://{hostname}/v1/auth/login
```

In subsequent requests, submit the token in the `Authorization` header:


```
curl -H 'Accept: application/json' -H "Authorization: Bearer ${TOKEN}" https://{hostname}/api/myresource
```
