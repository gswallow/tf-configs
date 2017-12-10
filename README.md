## Getting started

This project assumes you have a shared account with an S3 bucket to hold terraform remote state files.  To create such a bucket, run:

```
bundle install
bundle exec state/create_buckets.rb
```

You should only need to do this once.

## Initializing projects

For each project, change into the project directory, then run:

```
../state/create_backend.sh
terraform init
terraform workspace new $environment
```
