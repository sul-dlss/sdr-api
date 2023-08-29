[![CircleCI](https://circleci.com/gh/sul-dlss/sdr-api.svg?style=svg)](https://circleci.com/gh/sul-dlss/sdr-api)
[![Maintainability](https://api.codeclimate.com/v1/badges/6e11d54474bfaf70480b/maintainability)](https://codeclimate.com/github/sul-dlss/sdr-api/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/6e11d54474bfaf70480b/test_coverage)](https://codeclimate.com/github/sul-dlss/sdr-api/test_coverage)
[![OpenAPI Validator](http://validator.swagger.io/validator?url=https://raw.githubusercontent.com/sul-dlss/sdr-api/main/openapi.yml)](http://validator.swagger.io/validator/debug?url=https://raw.githubusercontent.com/sul-dlss/sdr-api/main/openapi.yml)

# Stanford Digital Repository API (SDR-API)

An HTTP API for the SDR.

There is a [OAS 3.0 spec](http://spec.openapis.org/oas/v3.0.2) that documents the API in [openapi.yml].  If you clone this repo, you can view this by opening [docs/index.html](docs/index.html).

## Functionality
### Deposit
This accepts a series of uploaded files and metadata (Cocina model) and begins the accessioning workflow.

### Register
Same as deposit, but doesn't begin the accessioning workflow

## Future enhancements
- Update an existing object. This depends on us having a complete mapping between Cocina descriptive metadata and MODS.
- Create derivative images for access

## Local Development / Usage

### Start dependencies

#### Database

```
docker compose up -d db
```

### Build the api container

```
docker compose build app
```

### Setup the local database

```
bin/rails db:create
bin/rails db:migrate
```

### Start the app

```
docker compose up -d app
```

### Authorization

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


### Sequence of operations

Given that we have a DRO with two Filesets each with a File (image1.png) and (image2.png)

1. Get base64 encoded md5 checksum of the files: `ruby -rdigest -e 'puts Digest::MD5.file("image1.png").base64digest'`
1. `curl -X POST -H 'Content-Type: application/json' -d '{"blob":{"byte_size":185464, "checksum":"Yw6eokcdYaqMAYioup0l7g==","content_type":"image/png","filename":"image.png"}}' http://localhost:3000/rails/active_storage/direct_uploads`
  This will return a payload with a `signed_id` and `direct_upload` object has the URL to send the file to.
1. PUT the content to the URL given in the previous step. _See warning below about behavior to watch for when depositing JSON content._
1. Repeat step 1-2 for the second file.
1. POST /filesets with the `signed_id` from step one.  Repeat for the second file. The API will use `ActiveStorage::Blob.find_signed(params[:signed_id])` to find the files.
1. POST /dro with the fileset ids from the previous step.

#### Gotcha to consider when PUTing JSON content for deposit

Despite our intent to accept user deposited content as given without further validation, some Rails and/or Committee magic is parsing content deposited as `application/json` in step 3 of the above sequence of operations. If the uploaded content does not parse as JSON, but does specify a content type of `application/json`, it will be rejected with a 400 error. You can work around this by using the custom `application/x-stanford-json` content type, which will be translated back to `application/json` before the Cocina is saved. See `/v1/disk/{id}` description in [`openapi.yml`](openapi.yml), and/or https://github.com/sul-dlss/happy-heron/issues/3075 for more context.

## User management
### Create a user
```
bin/rake "users:create[leland@stanford.edu]"
Password:
#<User:0x00007f8647ae4988> {
                 :id => 2,
               :name => nil,
              :email => "leland@stanford.edu",
    :password_digest => "[DIGEST]",
         :created_at => Fri, 18 Nov 2022 15:17:22.836184000 UTC +00:00,
         :updated_at => Fri, 18 Nov 2022 15:17:22.836184000 UTC +00:00,
             :active => true,
        :full_access => true,
        :collections => []
}
```

### Show a user
```
bin/rake "users:show[leland@stanford.edu]"
#<User:0x0000000113fbb6e8> {
                 :id => 1,
               :name => nil,
              :email => "leland@stanford.edu",
   "password_digest" => "[DIGEST]",
         :created_at => Thu, 17 Nov 2022 17:26:28.927725000 UTC +00:00,
         :updated_at => Thu, 17 Nov 2022 17:26:28.927725000 UTC +00:00,
             :active => true,
        :full_access => true,
        :collections => []
}
```

### Change whether active
```
bin/rake "users:active[leland@stanford.edu,false]"
#<User:0x00000001107805a8> {
             "active" => false,
                 "id" => 1,
               "name" => nil,
              :email => "leland@stanford.edu",
    "password_digest" => "[DIGEST]",
         "created_at" => Thu, 17 Nov 2022 17:26:28.927725000 UTC +00:00,
         "updated_at" => Thu, 17 Nov 2022 19:10:27.385608000 UTC +00:00,
        "full_access" => true,
        "collections" => []
}
```

### Add authorized collections and remove full-access
```
bin/rake "users:collections[leland@stanford.edu,'druid:bb408qn5061 druid:bb573tm8486']"
#<User:0x0000000107d0d240> {
        "collections" => [
        [0] "'druid:bb408qn5061",
        [1] "druid:bb573tm8486'"
    ],
        "full_access" => false,
                 "id" => 1,
               "name" => nil,
              :email => "leland@stanford.edu",
    "password_digest" => "[DIGEST]",
         "created_at" => Thu, 17 Nov 2022 17:26:28.927725000 UTC +00:00,
         "updated_at" => Thu, 17 Nov 2022 19:17:11.197967000 UTC +00:00,
             "active" => false
}
```

### Remove authorized collections and make full-access
```
 bin/rake "users:collections[leland@stanford.edu,'']"
#<User:0x0000000110b8f090> {
        "collections" => [],
        "full_access" => true,
                 "id" => 1,
               "name" => nil,
              :email => "leland@stanford.edu",
    "password_digest" => "[DIGEST]",
         "created_at" => Thu, 17 Nov 2022 17:26:28.927725000 UTC +00:00,
         "updated_at" => Thu, 17 Nov 2022 19:20:47.869335000 UTC +00:00,
             "active" => false
}
```


## Docker

Note that this project's continuous integration build will automatically create and publish an updated image whenever there is a passing build from the `main` branch. If you do need to manually create and publish an image, do the following:

Build image:
```
docker image build -t suldlss/sdr-api:latest .
```

Publish:
```
docker push suldlss/sdr-api:latest
```

## Background processing
Background processing is performed by [Sidekiq](https://github.com/mperham/sidekiq).

Sidekiq can be monitored from [/queues](http://localhost:3000/queues).
For more information on configuring and deploying Sidekiq, see this [doc](https://github.com/sul-dlss/DevOpsDocs/blob/master/projects/sul-requests/background_jobs.md).

# Cron check-ins
Cron jobs (configured via the whenever gem) are integrated with Honeybadger check-ins. These cron jobs will check-in with HB (via a curl request to an HB endpoint) whenever run. If a cron job does not check-in as expected, HB will alert.

Cron check-ins are configured in the following locations:
1. `config/schedule.rb`: This specifies which cron jobs check-in and what setting keys to use for the checkin key. See this file for more details.
2. `config/settings.yml`: Stubs out a check-in key for each cron job. Since we may not want to have a check-in for all environments, this stub key will be used and produce a null check-in.
3. `config/settings/production.yml` in shared_configs: This contains the actual check-in keys.
4. HB notification page: Check-ins are configured per project in HB. To configure a check-in, the cron schedule will be needed, which can be found with `bundle exec whenever`. After a check-in is created, the check-in key will be available. (If the URL is `https://api.honeybadger.io/v1/check_in/rkIdpB` then the check-in key will be `rkIdp`).

## Reset Process (for QA/Stage)

### Steps

1. Dump the users table: `pg_dump --table public.users --data-only sdr > users.sql`
2. Reset the database: `bin/rails -e p db:reset`
3. Restore the users table: `psql -f users.sql sdr`
4. Delete file storage: `rm -fr storage/*`
5. To test, run the `sdr_deposit_spec.rb` integration test.