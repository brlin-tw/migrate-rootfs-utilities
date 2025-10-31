# AI agent instruction file

This file contains instructions and guidelines for AI agents interacting with this repository. It outlines the expected behavior, coding standards, and collaboration protocols to ensure effective and efficient contributions.

## Bash coding style

The following coding style guidelines should be followed when writing Bash scripts:

### Shebang

Use `#!/usr/bin/env bash` as the shebang line for portability across different environments.

### Parameter naming

* Use lowercase letters and underscores for variable names (e.g., `my_variable`) to enhance readability.
* Only use uppercase letters for variables whose values are sourced from the environment.

### Parameter expansion

Use `${var}` instead of `$var` for variable references to improve readability and avoid ambiguity.

This also applies to positional parameters, e.g., use `${1}` instead of `$1`.

### Message reporting

* If the program's output is intended to be used as input for other programs, avoid implementing non-error messages at all.
* Use `printf` instead of `echo` for formatted output.
* Prepend log level tags in the following format(except for help text):
    + `Info:`
    + `Warning:`
    + `Error:`
    + `FATAL:`
    + `DEBUG:`

### Linting

Use ShellCheck for linting.

### Defensive interpreter behavior

The following shell options should be set at the beginning of each script to ensure robust error handling:

```bash
set -o errexit   # Exit on most errors (see the manual)
set -o nounset   # Disallow expansion of unset variables
```

Do not set `pipefail`.

If the script contains functions, also include:

```bash
set -o errtrace  # Ensure the error trap is inherited
```

### Conditional constructs

* When using `if...else` constructs, always check the incorrect condition first.  For example:

    ```bash
    if ! is_port_valid "${user_input}"; then
        printf \
            'Error: Invalid port number, please try again.\n' \
            1>&2
        return 1
    else
        # Do something when the condition is expected
    fi
    ```

* Use the `test` shell built-in for conditional expressions.  For example, use `if test -f "file"` instead of `if [[ -f "file" ]]`.

  The only exception is when using regex matching, which requires `[[ ... ]]`.  When doing so always define a regex_pattern variable instead of embedding the regex directly in the conditional expression.

### Pattern matching

* Use the `[[ ... ]]` construct for validating user inputs when applicable.

  Store the regex pattern in a `regex_` prefix variable instead of embedding it in the conditional expression.  For example:

   ```bash
    local regex_digits='^[[:digit:]]+$'
    if [[ "${user_input}" =~ ${regex_digits} ]]; then
        # Do something when the input is a number
    fi
    ```

### Passing data to subprocesses

* Using the Here Strings syntax (`<<<`) is preferred when passing small amounts of data to subprocesses.  For example:

    ```bash
    grep 'pattern' <<< "${data_variable}"
    ```

### Functions

* Use `function_name(){ ... }` syntax for defining functions. Do not use the `function` keyword.
* Always use `local` for function-local variables.
* Do not use global variables inside functions. Instead, pass them as arguments.
* Use the following pattern to retrieve function arguments:

    ```bash
    local var="${1}"; shift
    ```

  Always use `${1}` parameter expansion and append `shift` command even when the function only has one parameter. This allows cleaner diffs when adding or removing arguments.

* Validate input parameters at the beginning of functions
* Always use `return` to return an exit status from functions.  Only use the `exit` builtin in the `init`/`main` function as it is the main logic of the script.
* Place all non `init`/`main` functions _after_ the `init`/`main` function in the script. This allows script readers to access the main script logic easily.
* Use imperative tense for function names.

### Error Handling

* Always check the exit status of commands and handle errors appropriately, don't rely solely on the ERR trap.
* Do not use AND/OR lists syntax.

### Script template

The following script should be used for script creation, rewrites, and style references:

```bash
#!/usr/bin/env bash
# _script_description_
#
# Copyright _copyright_effective_year_ _copyright_holder_name_ <_copyright_holder_contact_>
# SPDX-License-Identifier: CC-BY-SA-4.0

init(){
    printf \
        'Info: Operation completed without errors.\n'
    exit 0
}

printf \
    'Info: Configuring the defensive interpreter behaviors...\n'
set_opts=(
    # Terminate script execution when an unhandled error occurs
    -o errexit
    -o errtrace

    # Terminate script execution when an unset parameter variable is
    # referenced
    -o nounset
)
if ! set "${set_opts[@]}"; then
    printf \
        'Error: Unable to configure the defensive interpreter behaviors.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Checking the existence of the required commands...\n'
required_commands=(
    realpath
)
flag_required_command_check_failed=false
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" >/dev/null; then
        flag_required_command_check_failed=true
        printf \
            'Error: This program requires the "%s" command to be available in your command search PATHs.\n' \
            "${command}" \
            1>&2
    fi
done
if test "${flag_required_command_check_failed}" == true; then
    printf \
        'Error: Required command check failed, please check your installation.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Configuring the convenience variables...\n'
if test -v BASH_SOURCE; then
    # Convenience variables may not need to be referenced
    # shellcheck disable=SC2034
    {
        printf \
            'Info: Determining the absolute path of the program...\n'
        if ! script="$(
            realpath \
                --strip \
                "${BASH_SOURCE[0]}"
            )"; then
            printf \
                'Error: Unable to determine the absolute path of the program.\n' \
                1>&2
            exit 1
        fi
        script_dir="${script%/*}"
        script_filename="${script##*/}"
        script_name="${script_filename%%.*}"
    }
fi
# Convenience variables may not need to be referenced
# shellcheck disable=SC2034
{
    script_basecommand="${0}"
    script_args=("${@}")
}

printf \
    'Info: Setting the ERR trap...\n'
trap_err(){
    printf \
        'Error: The program has encountered an unhandled error and is prematurely aborted.\n' \
        1>&2
}
if ! trap trap_err ERR; then
    printf \
        'Error: Unable to set the ERR trap.\n' \
        1>&2
    exit 1
fi

init
```
