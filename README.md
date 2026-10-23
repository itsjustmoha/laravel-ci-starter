# Laravel CI Starter

[![Self-test](https://github.com/itsjustmoha/laravel-ci-starter/actions/workflows/self-test.yml/badge.svg)](https://github.com/itsjustmoha/laravel-ci-starter/actions/workflows/self-test.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A drop-in GitHub Actions setup for Laravel apps. Copy three files, push, and every pull request gets:

- **Code style** checked with [Laravel Pint](https://laravel.com/docs/pint)
- **Static analysis** with [Larastan](https://github.com/larastan/larastan) at level 9, with PHPStan's result cache kept between runs
- **Tests** on each PHP version you support, with SQLite and your Vite assets built
- **A dependency audit** of `composer.lock` against known vulnerabilities
- **Dependabot** keeping your Actions, Composer and npm packages up to date in grouped weekly PRs

The template is tested every week against a brand-new Laravel app on PHP 8.3, 8.4 and 8.5. The self-test runs the template's own commands, so when a Laravel, Larastan or Pint release breaks something, the badge above turns red before your CI does.

## Quick start

From the root of your Laravel project:

```bash
base=https://raw.githubusercontent.com/itsjustmoha/laravel-ci-starter/main/template

mkdir -p .github/workflows
curl -fsSL "$base/.github/workflows/ci.yml" -o .github/workflows/ci.yml
curl -fsSL "$base/.github/dependabot.yml"   -o .github/dependabot.yml
curl -fsSL "$base/phpstan.neon"             -o phpstan.neon

composer require --dev larastan/larastan
```

These commands overwrite existing files with the same names. If you already have a `dependabot.yml` or `phpstan.neon`, merge them by hand.

Run the same checks locally before you push:

```bash
vendor/bin/pint --test
vendor/bin/phpstan analyse
php artisan test
```

## What's in the box

| File | Purpose |
| --- | --- |
| [`.github/workflows/ci.yml`](template/.github/workflows/ci.yml) | The CI workflow: three jobs, described below |
| [`.github/dependabot.yml`](template/.github/dependabot.yml) | Weekly grouped updates for Actions, Composer and npm |
| [`phpstan.neon`](template/phpstan.neon) | Larastan config: level 9 on `app/`, `database/` and `routes/` |

| Job | What it runs | Notes |
| --- | --- | --- |
| **Code quality** | `pint --test`, then `phpstan analyse` | Larastan runs even when Pint fails, so one push shows both reports. Larastan errors appear as annotations on the PR diff. |
| **Dependency audit** | `composer audit --locked` | Reads `composer.lock` directly, so it finishes in seconds. Fails on known vulnerabilities and on abandoned packages. |
| **Tests** | `php artisan test` on each PHP version in the matrix | Builds Vite assets first when there is a `package-lock.json`, because views using `@vite` throw in tests without a manifest. |

Runs on pushes to `main` and on every pull request. A new push to the same PR cancels the run that's still going.

## Adapting it

### PHP versions

The quality and audit jobs use `PHP_VERSION` at the top of the workflow. Set it to the version you deploy on.

The test matrix defaults to `8.4` and `8.5`. A `composer.lock` created on PHP 8.4 can contain packages that require 8.4, and `composer install` on 8.3 then fails. Add `'8.3'` only if your lock file installs there. One way to guarantee that is to pin the platform in `composer.json`:

```json
"config": {
    "platform": { "php": "8.3.0" }
}
```

### An existing project with many PHPStan errors

Level 9 on a large existing codebase will report a lot. Record the current state as a baseline once, then only new errors fail CI:

```bash
vendor/bin/phpstan analyse --generate-baseline
```

Uncomment `phpstan-baseline.neon` in `phpstan.neon` and commit both files. You can also lower `level` and raise it step by step.

### MySQL

Add a service and database variables to the `tests` job:

```yaml
  tests:
    # ...
    services:
      mysql:
        image: mysql:8.4
        env:
          MYSQL_DATABASE: testing
          MYSQL_ROOT_PASSWORD: password
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
    env:
      DB_CONNECTION: mysql
      DB_HOST: 127.0.0.1
      DB_PORT: 3306
      DB_DATABASE: testing
      DB_USERNAME: root
      DB_PASSWORD: password
```

### PostgreSQL

```yaml
  tests:
    # ...
    services:
      postgres:
        image: postgres:18
        env:
          POSTGRES_DB: testing
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: password
        ports:
          - 5432:5432
        options: >-
          --health-cmd=pg_isready
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
    env:
      DB_CONNECTION: pgsql
      DB_HOST: 127.0.0.1
      DB_PORT: 5432
      DB_DATABASE: testing
      DB_USERNAME: postgres
      DB_PASSWORD: password
```

If you use Laravel's vector search, swap the image for one of the [pgvector](https://hub.docker.com/r/pgvector/pgvector) images.

For either database, job-level `env` takes priority over `.env` and over the `<env>` entries in `phpunit.xml`, unless an entry there has `force="true"`.

### Code coverage

In the `tests` job, change `coverage: none` to `coverage: pcov` and run:

```yaml
      - name: Run tests
        run: php artisan test --coverage --min=80
```

### Parallel tests

Install [ParaTest](https://github.com/paratestphp/paratest) and add `--parallel`:

```bash
composer require --dev brianium/paratest
```

```yaml
      - name: Run tests
        run: php artisan test --parallel
```

### pnpm, Yarn or Bun

The Node steps only run when `package-lock.json` exists. With another package manager, change the condition, the `cache` input of `actions/setup-node` and the install command.

## How the self-test works

[`self-test.yml`](.github/workflows/self-test.yml) runs on every push and each Monday:

1. Lints all workflows with [actionlint](https://github.com/rhysd/actionlint), including the template.
2. Creates a fresh app with `composer create-project laravel/laravel` on PHP 8.3, 8.4 and 8.5.
3. Copies the template in and installs Larastan, as in the quick start.
4. Pulls the `run:` blocks out of `template/.github/workflows/ci.yml` by job and step name and executes them. It tests the exact commands you copy, not a second copy that could drift.

## License

[MIT](LICENSE)
