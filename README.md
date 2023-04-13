# Action pull request another repository
This GitHub Action copies the contents of a folder (not the folder itself) from the current repository to a location in another repository and creates a Pull Request

## Example Workflow
    name: Push File

    on: push

    jobs:
      pull-request:
        runs-on: ubuntu-latest
        steps:
        - name: Checkout
          uses: actions/checkout@v3

        - name: Create pull request
          uses: slgriffiths/action-pull-request-another-repo@v1.0.0
          with:
            github_token: ${{ secrets.CUSTOM_GH_TOKEN }}      # If blank, default: secrets.GITHUB_TOKEN
            source_folder: 'source-folder'                    # Folder name to copy contents from
            destination_repo: 'user-name/repository-name'     # Remote repo creating PR in
            destination_folder: 'folder-name'                 # Directory to have source folder contents copied into
            destination_base_branch: 'branch-name'            # Base branch to create PR against
            destination_head_branch: 'branch-name'            # Name of the branch for this new PR
            pr_title: "Pulling ${{ github.ref }} into main"   # Title of pull request
            pr_body: |                                        # Full markdown support, requires pr_title to be set
              :crown: *An automated PR*

              My cool PR body.
            pr_reviewer: "user1,user2"                        # Comma-separated list (no spaces)
            pr_assignee: "user1,user2"                        # Comma-separated list (no spaces)
            pr_label: "auto-pr,another label"                 # Comma-separated list (no spaces)
            pr_milestone: "Milestone 1"                       # Milestone name
            pr_draft: true                                    # Creates pull request as draft

## Behavior Notes
The action will create any destination paths if they don't exist. It will also overwrite existing files if they already exist in the locations being copied to. It will not delete the entire destination repository.
