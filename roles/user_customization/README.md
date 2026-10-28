# user_customization

Deploys user dotfiles.

## What it does

- Writes `<home>/.vimrc` (mode 0644, owned by the user and the group of the same name) from
  `user_customization_vimrc` for each entry of `user_customization_users` (root and the operator by default).
  The users must exist: the `operator_user` role runs first.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `user_customization_vimrc` | str | multi-line value, see `defaults/main.yml` | no | Content of the `.vimrc` written for every listed user. The default is a plain editing setup. |
| `user_customization_users` | list of dict | `[{name: root, home: /root}, {name: operator, home: /home/...` (2 entries, truncated, see `defaults/main.yml`) | no | Users receiving the `.vimrc`. The name is also the file owner and group. |
| `user_customization_users[].name` | str | none | yes | Account name, used as owner and group. |
| `user_customization_users[].home` | str | none | yes | Home directory holding the `.vimrc`. |
<!-- END VARIABLES -->
