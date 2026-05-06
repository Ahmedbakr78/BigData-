import os
import re

def strip_java_comments(code):
    # Strip /* ... */ and // ...
    # This simple regex works as long as there are no comment sequences in string literals
    # which is true for our code.
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
    code = re.sub(r'//.*', '', code)
    # remove empty lines
    lines = [line.rstrip() for line in code.split('\n')]
    return '\n'.join([line for line in lines if line.strip()])

def strip_sh_comments(code):
    lines = code.split('\n')
    new_lines = []
    for i, line in enumerate(lines):
        if line.strip().startswith('#') and not line.strip().startswith('#!'):
            continue
        # also handle inline comments if any, but let's be careful with # in string literals.
        # our sh scripts have # for colors and things? Wait, no, colors are \033[0;31m.
        # Let's just remove lines starting with #.
        if line.strip().startswith('#') and not line.startswith('#!'):
            pass
        else:
            # check for inline \#
            # our scripts only use # at the start or after whitespace for comments.
            if ' #' in line:
                line = line.split(' #')[0]
            new_lines.append(line.rstrip())
    return '\n'.join([line for line in new_lines if line.strip() or line == ''])

for root, dirs, files in os.walk('.'):
    for f in files:
        path = os.path.join(root, f)
        if f.endswith('.java'):
            with open(path, 'r') as file:
                code = file.read()
            clean_code = strip_java_comments(code)
            with open(path, 'w') as file:
                file.write(clean_code)
            print(f"Cleaned {path}")
            
        elif f.endswith('.sh') or f == 'Dockerfile':
            with open(path, 'r') as file:
                code = file.read()
            clean_code = strip_sh_comments(code)
            with open(path, 'w') as file:
                file.write(clean_code)
            print(f"Cleaned {path}")
