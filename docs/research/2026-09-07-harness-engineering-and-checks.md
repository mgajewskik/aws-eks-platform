# Harness engineering and checks for an AWS EKS platform

- Date: 2026-09-07
- Status: research findings and their application to this repository
- Scope: repository guidance, documentation layout, and local checks
- Non-goals: selecting a GitOps engine, running live AWS mutations, or defining product architecture

## Sources

- [OpenAI, Harness engineering](https://openai.com/index/harness-engineering/)
- [AGENTS.md format](https://agents.md/)
- [Terraform `fmt`](https://developer.hashicorp.com/terraform/cli/commands/fmt)
- [Terraform `validate`](https://developer.hashicorp.com/terraform/cli/commands/validate) and [format and validate](https://developer.hashicorp.com/terraform/cli/code)
- [Aqua tfsec README](https://github.com/aquasecurity/tfsec), [migration guide](https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md), and [Trivy Terraform coverage](https://trivy.dev/docs/latest/coverage/iac/terraform/)
- [Trivy exit code](https://trivy.dev/docs/latest/guide/configuration/others/) and [built-in checks](https://trivy.dev/docs/latest/scanner/misconfiguration/check/builtin/)
- [Infracost](https://www.infracost.io/docs/), [environment variables](https://www.infracost.io/docs/features/environment_variables/), and [plan JSON](https://www.infracost.io/docs/features/terraform_plan_json/)
- [TFLint](https://github.com/terraform-linters/tflint), [pre-commit](https://pre-commit.com/), and [mise tasks](https://mise.jdx.dev/tasks/)
- [kubeconform](https://github.com/yannh/kubeconform), [yamllint](https://yamllint.readthedocs.io/en/stable/), and [ShellCheck](https://github.com/koalaman/shellcheck)
- [A concise `ARCHITECTURE.md`](https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html)

## Findings

OpenAI's harness account describes repository guidance as a map, durable project knowledge as versioned documentation, and recurring failures as opportunities for mechanical checks. The public [AGENTS.md format](https://agents.md/) also frames the file as agent-facing instructions. These ideas fit an infrastructure repository when applied with clear ownership and safe feedback loops; the product's scale and automation choices do not need to be copied wholesale.

Repository instructions should point to the relevant local procedures rather than repeat them. Plans, decisions, architecture, runbooks, and research serve different purposes and belong in versioned documentation. A short architecture map should answer where major components live and state lifecycle boundaries; it need not become a tutorial ([matklad](https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html)).

Required checks should be repeatable, fail on defects, and avoid changing cloud resources. Bind checks as the corresponding files and tools are introduced; empty optional trees should not make the suite fail. Keep Terraform configuration and GitOps desired state under their respective ownership boundaries. Never make `terraform apply`, `terraform destroy`, or real-cluster mutation part of a default check.

### Check capabilities and limits

- `terraform fmt -check -recursive` detects formatting drift without rewriting files. `terraform validate` checks configuration syntax and internal consistency, but not remote services; it needs an initialized working directory. `terraform init -backend=false` avoids backend initialization but can still download providers or modules ([`fmt`](https://developer.hashicorp.com/terraform/cli/commands/fmt), [`validate`](https://developer.hashicorp.com/terraform/cli/commands/validate), [overview](https://developer.hashicorp.com/terraform/cli/code)).
- TFLint provides Terraform-language rules and can use a separately configured AWS ruleset. Initializing plugins needs network access, not AWS API access ([TFLint](https://github.com/terraform-linters/tflint)).
- Aqua directs tfsec users toward Trivy. `trivy config` scans infrastructure configuration; findings only fail a gate when a non-zero `--exit-code` is set. Trivy can fetch its checks bundle, with embedded checks available as fallback ([tfsec migration guide](https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md), [Terraform coverage](https://trivy.dev/docs/latest/coverage/iac/terraform/), [exit code](https://trivy.dev/docs/latest/guide/configuration/others/), [checks bundle](https://trivy.dev/docs/latest/scanner/misconfiguration/check/builtin/)).
- `yamllint` checks YAML syntax and style; kubeconform checks Kubernetes schemas, not server admission. Custom-resource schemas need to be supplied. ShellCheck analyzes shell scripts ([yamllint](https://yamllint.readthedocs.io/en/stable/), [kubeconform](https://github.com/yannh/kubeconform), [ShellCheck](https://github.com/koalaman/shellcheck)).
- pre-commit is suited to staged-file hooks and may run formatters that change files. A repository check task can cover the full tree in check-only mode. A formatter hook and a check-only formatting gate serve different purposes; duplicate scanners add maintenance without creating a clearer result ([pre-commit](https://pre-commit.com/), [mise tasks](https://mise.jdx.dev/tasks/)).
- Infracost is a separate, authenticated cost-analysis path. HCL analysis and plan-JSON analysis have different inputs; the latter depends on a Terraform plan. Keep cost analysis explicitly selected rather than making it a required check ([Infracost](https://www.infracost.io/docs/), [environment variables](https://www.infracost.io/docs/features/environment_variables/), [plan JSON](https://www.infracost.io/docs/features/terraform_plan_json/)).

## Application in this repository

Terraform owns the AWS platform foundation, while GitOps owns desired cluster state. The repository uses `AGENTS.md` as the workflow map and `docs/dev/harness.md` for workflow details. Repository-local planner, implementer, and reviewer skills define those procedures. A living plan records criteria and anti-criteria; implementation includes affected documentation; required checks run before an independent review. The owner decides when to commit, publish, or deploy.

The required local check command is `mise run checks` (through `rtk proxy` in an interactive shell). It runs pytest harness tests, Terraform formatting, conditional validation and TFLint, and Trivy misconfiguration and secret scans. Empty Terraform or GitOps checks report skips. The separate `mise run docs-gate -- --plan <plan-path>` command checks documentation evidence when closing a Feature; it is not part of routine checks. These commands do not apply infrastructure or require AWS credentials. Initialization and scanner policy refresh can still use the network. A passing local check does not prove deployed security, availability, or behavior.

Keep cost estimation, Terraform plans, live tests, and workload scenarios outside required checks. They need explicit selection and, where applicable, the owner's credentials and review of the target. The owner runs deployment from a local machine. Tests do not provision or destroy the platform.
