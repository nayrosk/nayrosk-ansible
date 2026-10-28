# user_customization

Deploys user dotfiles.

## What it does

- Writes `<home>/.vimrc` (mode 0644, owned by the user and the group of the same name) from
  `user_customization_vimrc` for each entry of `user_customization_users` (root and the operator by default).
  The users must exist: the `operator_user` role runs first.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `user_customization_vimrc` | str | see `defaults/main.yml` | Content of the `.vimrc` written for every listed user. See the role defaults. |
| `user_customization_users` | list | `[{name: root, home: /root}, {name: operator, home: /home/operator}]` | Users receiving the `.vimrc`. The name is also the file owner and group. |
<!-- END VARIABLES -->
