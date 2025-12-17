---
name: github-actions
description: GitHub Actions workflow authoring, CI/CD pipelines, custom actions, and debugging. Covers triggers, jobs, matrix builds, secrets, reusable workflows, and common patterns.
---

# GitHub Actions Skill

## Overview

Author and maintain GitHub Actions workflows for CI/CD automation. This skill covers workflow syntax, triggers, job configuration, secrets management, reusable workflows, and debugging techniques.

## When to Use

- Creating CI/CD pipelines
- Authoring custom GitHub Actions
- Setting up automated testing and deployments
- Debugging failing workflows
- Implementing matrix builds
- Managing secrets and environments

## Workflow Basics

### Minimal Workflow

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
```

### Full Workflow Structure

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

env:
  NODE_VERSION: '20'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      - run: npm ci
      - run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: ./deploy.sh
```

## Triggers

### Push and Pull Request

```yaml
on:
  push:
    branches:
      - main
      - 'release/*'
    paths:
      - 'src/**'
      - '!src/**/*.md'
    tags:
      - 'v*'

  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]
```

### Schedule (Cron)

```yaml
on:
  schedule:
    # Run at 00:00 UTC every day
    - cron: '0 0 * * *'
    # Run at 06:00 UTC Monday-Friday
    - cron: '0 6 * * 1-5'
```

### Manual Trigger

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy'
        required: true
        type: string
      dry_run:
        description: 'Dry run mode'
        required: false
        type: boolean
        default: false
```

### Workflow Call (Reusable)

```yaml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy_key:
        required: true
```

### Other Triggers

```yaml
on:
  release:
    types: [published, created]

  issue_comment:
    types: [created]

  repository_dispatch:
    types: [deploy-command]
```

## Jobs and Steps

### Job Dependencies

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building..."

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Testing..."

  deploy:
    needs: [build, test]
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying..."
```

### Job Outputs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.value }}
    steps:
      - id: version
        run: echo "value=1.0.0" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying version ${{ needs.build.outputs.version }}"
```

### Conditional Execution

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to prod
        if: contains(github.event.head_commit.message, '[deploy]')
        run: ./deploy.sh
```

## Matrix Builds

### Basic Matrix

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20, 22]
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

### Matrix with Include/Exclude

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        node: [18, 20]
        include:
          - os: ubuntu-latest
            node: 22
            experimental: true
        exclude:
          - os: windows-latest
            node: 18
    runs-on: ${{ matrix.os }}
    continue-on-error: ${{ matrix.experimental || false }}
```

## Secrets and Variables

### Using Secrets

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.API_KEY }}
        run: ./deploy.sh

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
```

### Environment Secrets

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy
        env:
          # Uses production environment secret
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: ./deploy.sh
```

### Variables

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying to ${{ vars.DEPLOY_TARGET }}"
```

## Contexts and Expressions

### Common Contexts

```yaml
steps:
  - run: |
      echo "Repo: ${{ github.repository }}"
      echo "Branch: ${{ github.ref_name }}"
      echo "SHA: ${{ github.sha }}"
      echo "Actor: ${{ github.actor }}"
      echo "Event: ${{ github.event_name }}"
      echo "Run ID: ${{ github.run_id }}"
      echo "Run Number: ${{ github.run_number }}"
```

### Expression Functions

```yaml
steps:
  - if: contains(github.event.head_commit.message, '[skip ci]')
    run: exit 0

  - if: startsWith(github.ref, 'refs/tags/')
    run: echo "This is a tag"

  - if: always()
    run: echo "Always runs"

  - if: failure()
    run: echo "Only on failure"

  - if: success()
    run: echo "Only on success"

  - env:
      IS_MAIN: ${{ github.ref == 'refs/heads/main' && 'true' || 'false' }}
    run: echo "Is main: $IS_MAIN"
```

### JSON Functions

```yaml
steps:
  - run: echo '${{ toJSON(github.event) }}'
  - run: echo '${{ fromJSON(needs.build.outputs.matrix) }}'
```

## Reusable Workflows

### Define Reusable Workflow

`.github/workflows/reusable-build.yml`:
```yaml
name: Reusable Build

on:
  workflow_call:
    inputs:
      node-version:
        required: false
        type: string
        default: '20'
    outputs:
      artifact-name:
        description: "Name of the build artifact"
        value: ${{ jobs.build.outputs.artifact-name }}
    secrets:
      npm-token:
        required: false

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact-name: ${{ steps.build.outputs.name }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
      - run: npm ci
        env:
          NPM_TOKEN: ${{ secrets.npm-token }}
      - id: build
        run: |
          npm run build
          echo "name=build-${{ github.sha }}" >> $GITHUB_OUTPUT
```

### Call Reusable Workflow

```yaml
jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
    secrets:
      npm-token: ${{ secrets.NPM_TOKEN }}
    # Or inherit all secrets:
    # secrets: inherit

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Artifact: ${{ needs.build.outputs.artifact-name }}"
```

## Common Patterns

### Caching

```yaml
steps:
  - uses: actions/cache@v4
    with:
      path: ~/.npm
      key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-npm-

  - uses: actions/cache@v4
    with:
      path: |
        ~/.cache/go-build
        ~/go/pkg/mod
      key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
```

### Artifacts

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 5

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/
```

### Docker Build and Push

```yaml
jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Release Automation

```yaml
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: make build

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/*.tar.gz
            dist/*.zip
          generate_release_notes: true
```

## Debugging

### Enable Debug Logging

Set repository secrets:
- `ACTIONS_RUNNER_DEBUG`: `true`
- `ACTIONS_STEP_DEBUG`: `true`

### Debug Steps

```yaml
steps:
  - name: Debug info
    run: |
      echo "Event: ${{ github.event_name }}"
      echo "Ref: ${{ github.ref }}"
      cat $GITHUB_EVENT_PATH | jq .

  - name: Dump contexts
    env:
      GITHUB_CONTEXT: ${{ toJSON(github) }}
      JOB_CONTEXT: ${{ toJSON(job) }}
    run: |
      echo "$GITHUB_CONTEXT"
      echo "$JOB_CONTEXT"
```

### Local Testing with act

```bash
# Install act
brew install act

# Run default workflow
act

# Run specific workflow
act -W .github/workflows/ci.yml

# Run specific job
act -j test

# With secrets
act -s MY_SECRET=value

# Dry run
act -n
```

## Security Best Practices

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      # Pin actions to SHA for security
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1

      # Never echo secrets
      - run: ./script.sh
        env:
          TOKEN: ${{ secrets.TOKEN }}

      # Use GITHUB_TOKEN instead of PAT when possible
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Success Criteria

- Workflows trigger on correct events
- Jobs execute in correct order
- Secrets are never exposed in logs
- Caching improves build times
- Matrix builds cover required configurations
- Reusable workflows reduce duplication
