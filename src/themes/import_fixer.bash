#!/bin/bash

# Loop over each TypeScript file in the custom/ directory
find custom -name '*.ts' | while read customFile; do
  # Compute the corresponding file path in PEDSpace
  pedspaceFile=$(echo "$customFile" | sed 's|custom|PEDSpace|')

  if [ -f "$pedspaceFile" ]; then
    echo "Checking $customFile against $pedspaceFile"

    missingImports=""

    # Loop over each import line in the custom file
    while IFS= read -r importLine; do
      # Check if the PEDSpace file already has that import
      if ! grep -Fq "$importLine" "$pedspaceFile"; then
        echo "  Adding missing import to $pedspaceFile:"
        echo "    $importLine"
        missingImports="${missingImports}${importLine}"$'\n'
      fi
    done < <(grep '^import ' "$customFile")

    # Prepend missing imports to the PEDSpace file
    if [ -n "$missingImports" ]; then
      (echo "$missingImports"; cat "$pedspaceFile") > "$pedspaceFile.tmp" && mv "$pedspaceFile.tmp" "$pedspaceFile"
    fi

  else
    echo "No corresponding PEDSpace file for $customFile"
  fi
done

