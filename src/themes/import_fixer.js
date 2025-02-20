const fs = require('fs');
const path = require('path');

// Function to extract imports from a TypeScript file
function extractImports(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const importLines = [];
  const importRegex = /import\s+(?:{[\s\S]*?}|\*\s+as\s+\w+|\w+)\s+from\s+['"]([^'"]+)['"]/g;
  
  let match;
  while ((match = importRegex.exec(content)) !== null) {
    importLines.push({
      fullLine: match[0],
      importPath: match[1]
    });
  }
  
  return importLines;
}

// Function to extract component decorator imports
function extractComponentImports(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const componentRegex = /@Component\(\s*{[\s\S]*?imports:\s*\[([\s\S]*?)\][\s\S]*?}\s*\)/;
  
  const match = componentRegex.exec(content);
  if (match) {
    return match[1].trim().split(',').map(imp => imp.trim()).filter(imp => imp !== '');
  }
  
  return null;
}

// Function to extract constructor parameters
function extractConstructorParams(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const constructorRegex = /constructor\s*\(([\s\S]*?)\)\s*{/;
  
  const match = constructorRegex.exec(content);
  if (match) {
    return match[1].trim();
  }
  
  return null;
}

// Function to sync imports from custom to PEDSpace
async function syncImports() {
  // Get list of TypeScript files in custom directory
  const customTsFiles = fs.readFileSync('custom_ts_files.txt', 'utf8')
    .split('\n')
    .filter(file => file.trim() !== '' && file.endsWith('.ts'));
  
  let updatedFiles = 0;
  let unchangedFiles = 0;
  let errorFiles = 0;
  
  for (const customFilePath of customTsFiles) {
    // Calculate the corresponding path in PEDSpace
    const pedSpacePath = customFilePath.replace(/^custom\//, 'PEDSpace/');
    
    // Skip if the PEDSpace file doesn't exist
    if (!fs.existsSync(pedSpacePath)) {
      console.log(`Skipping: PEDSpace equivalent doesn't exist for ${customFilePath}`);
      continue;
    }
    
    try {
      // Extract imports from both files
      const customImports = extractImports(customFilePath);
      let pedSpaceContent = fs.readFileSync(pedSpacePath, 'utf8');
      
      // 1. Process regular imports
      let hasChanges = false;
      
      for (const importInfo of customImports) {
        // Check if this exact import already exists in the PEDSpace file
        if (!pedSpaceContent.includes(importInfo.fullLine)) {
          // Replace existing import for the same module or add if not exists
          const existingImportRegex = new RegExp(`import\\s+(?:{[\\s\\S]*?}|\\*\\s+as\\s+\\w+|\\w+)\\s+from\\s+['"]${importInfo.importPath.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')}['"]`, 'g');
          
          if (existingImportRegex.test(pedSpaceContent)) {
            // Replace existing import with the one from custom
            pedSpaceContent = pedSpaceContent.replace(existingImportRegex, importInfo.fullLine);
          } else {
            // Add new import at the top of the file
            const insertPosition = pedSpaceContent.search(/^(?!import\b).*$/m);
            if (insertPosition !== -1) {
              pedSpaceContent = 
                pedSpaceContent.substring(0, insertPosition) +
                importInfo.fullLine + '\n' +
                pedSpaceContent.substring(insertPosition);
            } else {
              pedSpaceContent = importInfo.fullLine + '\n' + pedSpaceContent;
            }
          }
          hasChanges = true;
        }
      }
      
      // 2. Process @Component imports
      const customComponentImports = extractComponentImports(customFilePath);
      if (customComponentImports) {
        const pedSpaceComponentImportsMatch = /@Component\(\s*{[\s\S]*?imports:\s*\[([\s\S]*?)\][\s\S]*?}\s*\)/.exec(pedSpaceContent);
        
        if (pedSpaceComponentImportsMatch) {
          const pedSpaceComponentImports = pedSpaceComponentImportsMatch[1].trim().split(',').map(imp => imp.trim()).filter(imp => imp !== '');
          const mergedImports = Array.from(new Set([...pedSpaceComponentImports, ...customComponentImports]));
          
          if (mergedImports.length !== pedSpaceComponentImports.length) {
            const formattedImports = mergedImports.join(',\n    ');
            pedSpaceContent = pedSpaceContent.replace(
              pedSpaceComponentImportsMatch[0],
              pedSpaceComponentImportsMatch[0].replace(
                pedSpaceComponentImportsMatch[1],
                `\n    ${formattedImports}\n  `
              )
            );
            hasChanges = true;
          }
        }
      }
      
      // 3. Process constructor parameters
      const customConstructorParams = extractConstructorParams(customFilePath);
      if (customConstructorParams) {
        const pedSpaceConstructorMatch = /constructor\s*\(([\s\S]*?)\)\s*{/.exec(pedSpaceContent);
        
        if (pedSpaceConstructorMatch) {
          const existingParams = pedSpaceConstructorMatch[1].trim();
          
          // Only replace if different
          if (existingParams !== customConstructorParams) {
            pedSpaceContent = pedSpaceContent.replace(
              pedSpaceConstructorMatch[0],
              `constructor(${customConstructorParams}) {`
            );
            hasChanges = true;
          }
        }
      }
      
      // Write updated content if changes were made
      if (hasChanges) {
        fs.writeFileSync(pedSpacePath, pedSpaceContent);
        console.log(`Updated in: ${pedSpacePath}`);
        updatedFiles++;
      } else {
        console.log(`No changes needed for: ${pedSpacePath}`);
        unchangedFiles++;
      }
    } catch (error) {
      console.error(`Error processing file ${customFilePath}: ${error.message}`);
      errorFiles++;
    }
  }
  
  console.log('\nSynchronization Summary:');
  console.log(`Total files processed: ${customTsFiles.length}`);
  console.log(`Files updated: ${updatedFiles}`);
  console.log(`Files unchanged: ${unchangedFiles}`);
  console.log(`Errors encountered: ${errorFiles}`);
}

// Function to generate the list of TypeScript files
function generateTsFileList() {
  const { execSync } = require('child_process');
  try {
    execSync('find custom/ -name "*.ts" > custom_ts_files.txt');
    console.log('TypeScript file list generated successfully');
  } catch (error) {
    console.error('Failed to generate TypeScript file list:', error.message);
    process.exit(1);
  }
}

// Main execution
generateTsFileList();
syncImports().catch(err => {
  console.error('Synchronization failed:', err);
  process.exit(1);
});