# Align the label, category, and ::= columns of BNFC production rules.
# Usage: awk -f scripts/align-bnfc.awk grammar/ArithmeticLambda.cf

function emit_rules(    i) {
    for (i = 1; i <= line_count; i++) {
        if (is_rule[i]) {
            printf "%-*s %-*s ::= %s\n", label_width, labels[i], category_width, categories[i], right_sides[i]
        } else {
            print lines[i]
        }
    }
}

{
    line_count++
    lines[line_count] = $0

    # A production starts with a label ending in '.', then a category and ::=.
    if ($0 !~ /^[[:alnum:]_]+\.[[:space:]]+[^[:space:]]+[[:space:]]+::=[[:space:]]*/) {
        next
    }

    split($0, fields, /[[:space:]]+/)
    labels[line_count] = fields[1]
    categories[line_count] = fields[2]
    right_sides[line_count] = $0
    sub(/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+::=[[:space:]]*/, "", right_sides[line_count])
    is_rule[line_count] = 1

    if (length(labels[line_count]) > label_width) {
        label_width = length(labels[line_count])
    }
    if (length(categories[line_count]) > category_width) {
        category_width = length(categories[line_count])
    }
}

END {
    emit_rules()
}
