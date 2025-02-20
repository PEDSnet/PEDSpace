import json5
import re

def generate_schemas(types, schema_pattern, text_pattern, type_mapping):
    schemas = []
    for type_name in types:
        schema = schema_pattern.replace('[]', f"{type_name.lower()}")
        human_readable_type = type_mapping.get(type_name, type_name)
        text = text_pattern.replace('[type]', human_readable_type)
        schemas.append(f'  "{schema}": "{text}"')
    return sorted(schemas)

def update_json_file(file_path, new_schemas):
    # Read the existing JSON5 file
    with open(file_path, 'r') as file:
        content = file.read()

    # Find the position to insert new schemas (just before the last closing brace)
    insert_position = content.rfind('}')

    # Check if we need to add a comma
    need_comma = True
    for i in range(insert_position - 1, -1, -1):
        if content[i].strip():
            if content[i] != ',':
                need_comma = True
            else:
                need_comma = False
            break
        if content[i] == '\n':
            need_comma = False
            break

    # Insert new schemas
    updated_content = content[:insert_position]
    if need_comma:
        updated_content += ','
    updated_content += '\n\n' + ',\n\n'.join(new_schemas) + '\n\n' + content[insert_position:]

    # Write the updated content back to the file
    with open(file_path, 'w') as file:
        file.write(updated_content)

def get_types(type_choice):
    if type_choice.lower() == 'e':
        return [
            "none", "Publication", "Person", "Project", "OrgUnit", "Journal", "JournalVolume",
            "JournalIssue", "DQCheck", "Documentation", "Phenotype", "Study", "ConceptSet"
        ]
    elif type_choice.lower() == 'r':
        return [
            "isAuthorOfPublication", "isPublicationOfAuthor", "isProjectOfPublication",
            "isPublicationOfProject", "isOrgUnitOfPublication", "isPublicationOfOrgUnit",
            "isProjectOfPerson", "isPersonOfProject", "isOrgUnitOfPerson", "isPersonOfOrgUnit",
            "isOrgUnitOfProject", "isProjectOfOrgUnit", "isVolumeOfJournal", "isJournalOfVolume",
            "isIssueOfJournalVolume", "isJournalVolumeOfIssue", "isPublicationOfJournalIssue",
            "isJournalIssueOfPublication", "resultsInPhenotype", "isResultOfStudy",
            "resultsInConceptSet", "informsPhenotype", "isInformedByConceptSet", "createsDQCheck",
            "isCreatedByPerson", "createsDocumentation", "createsPhenotype", "conductsStudy",
            "isConductedByPerson", "hasPerson", "isPartOfOrgUnit", "hasConceptSet",
            "isAssociatedWithOrgUnit", "isConductedByOrgUnit", "createsConceptSet", "isUsedInStudy",
            "usesConceptSet", "isDQCheckOfConceptSet", "isConceptSetOfDQCheck",
            "isDocumentationOfConceptSet", "isConceptSetOfDocumentation", "isMemberOfOrgUnit",
            "isConceptSetOfOrgUnit", "isOrgUnitOfConceptSet", "isStudyOfOrgUnit", "isOrgUnitOfStudy",
            "isAuthorOfConceptSet", "isConceptSetOfAuthor", "isEditorOfConceptSet",
            "isConceptSetOfEditor", "isStudyOfAuthor", "isAuthorOfStudy", "isStudyOfEditor",
            "isEditorOfStudy", "isStudyOfConceptSet", "isConceptSetOfStudy", "isDQCheckOfPerson",
            "isPersonOfDQCheck", "isDocumentationOfAuthor", "isAuthorOfDocumentation",
            "isDocumentationOfEditor", "isEditorOfDocumentation", "isPhenotypeOfAuthor",
            "isAuthorOfPhenotype", "isPhenotypeOfEditor", "isEditorOfPhenotype", "isPhenotypeOfStudy",
            "isStudyOfPhenotype", "isPhenotypeOfConceptSet", "isConceptSetOfPhenotype",
            "isMemberOfOrgUnit", "isOrgUnitOfPerson"
        ]
    else:
        return []

def get_type_mapping():
    return {
        "none": "None",
        "Publication": "Publication",
        "Person": "Person",
        "Project": "Project",
        "OrgUnit": "Organization Unit",
        "Journal": "Journal",
        "JournalVolume": "Journal Volume",
        "JournalIssue": "Journal Issue",
        "DQCheck": "DQ Check",
        "Documentation": "Documentation",
        "Phenotype": "Phenotype",
        "Study": "Study",
        "ConceptSet": "Concept Set",
        "isAuthorOfPublication": "is Author of Publication",
        "isPublicationOfAuthor": "is Publication of Author",
        "isProjectOfPublication": "is Project of Publication",
        "isPublicationOfProject": "is Publication of Project",
        "isOrgUnitOfPublication": "is Organization Unit of Publication",
        "isPublicationOfOrgUnit": "is Publication of Organization Unit",
        "isProjectOfPerson": "is Project of Person",
        "isPersonOfProject": "is Person of Project",
        "isOrgUnitOfPerson": "is Organization Unit of Person",
        "isPersonOfOrgUnit": "is Person of Organization Unit",
        "isOrgUnitOfProject": "is Organization Unit of Project",
        "isProjectOfOrgUnit": "is Project of Organization Unit",
        "isVolumeOfJournal": "is Volume of Journal",
        "isJournalOfVolume": "is Journal of Volume",
        "isIssueOfJournalVolume": "is Issue of Journal Volume",
        "isJournalVolumeOfIssue": "is Journal Volume of Issue",
        "isPublicationOfJournalIssue": "is Publication of Journal Issue",
        "isJournalIssueOfPublication": "is Journal Issue of Publication",
        "resultsInPhenotype": "results in Phenotype",
        "isResultOfStudy": "is Result of Study",
        "resultsInConceptSet": "results in Concept Set",
        "informsPhenotype": "informs Phenotype",
        "isInformedByConceptSet": "is Informed by Concept Set",
        "createsDQCheck": "creates DQ Check",
        "isCreatedByPerson": "is Created by Person",
        "createsDocumentation": "creates Documentation",
        "createsPhenotype": "creates Phenotype",
        "conductsStudy": "conducts Study",
        "isConductedByPerson": "is Conducted by Person",
        "hasPerson": "has Person",
        "isPartOfOrgUnit": "is Part of Organization Unit",
        "hasConceptSet": "has Concept Set",
        "isAssociatedWithOrgUnit": "is Associated with Organization Unit",
        "isConductedByOrgUnit": "is Conducted by Organization Unit",
        "createsConceptSet": "creates Concept Set",
        "isUsedInStudy": "is Used in Study",
        "usesConceptSet": "uses Concept Set",
        "isDQCheckOfConceptSet": "is DQ Check of Concept Set",
        "isConceptSetOfDQCheck": "is Concept Set of DQ Check",
        "isDocumentationOfConceptSet": "is Documentation of Concept Set",
        "isConceptSetOfDocumentation": "is Concept Set of Documentation",
        "isMemberOfOrgUnit": "is Member of Organization Unit",
        "isConceptSetOfOrgUnit": "is Concept Set of Organization Unit",
        "isOrgUnitOfConceptSet": "is Organization Unit of Concept Set",
        "isStudyOfOrgUnit": "is Study of Organization Unit",
        "isOrgUnitOfStudy": "is Organization Unit of Study",
        "isAuthorOfConceptSet": "is Author of Concept Set",
        "isConceptSetOfAuthor": "is Concept Set of Author",
        "isEditorOfConceptSet": "is Editor of Concept Set",
        "isConceptSetOfEditor": "is Concept Set of Editor",
        "isStudyOfAuthor": "is Study of Author",
        "isAuthorOfStudy": "is Author of Study",
        "isStudyOfEditor": "is Study of Editor",
        "isEditorOfStudy": "is Editor of Study",
        "isStudyOfConceptSet": "is Study of Concept Set",
        "isConceptSetOfStudy": "is Concept Set of Study",
        "isDQCheckOfPerson": "is DQ Check of Person",
        "isPersonOfDQCheck": "is Person of DQ Check",
        "isDocumentationOfAuthor": "is Documentation of Author",
        "isAuthorOfDocumentation": "is Author of Documentation",
        "isDocumentationOfEditor": "is Documentation of Editor",
        "isEditorOfDocumentation": "is Editor of Documentation",
        "isPhenotypeOfAuthor": "is Phenotype of Author",
        "isAuthorOfPhenotype": "is Author of Phenotype",
        "isPhenotypeOfEditor": "is Phenotype of Editor",
        "isEditorOfPhenotype": "is Editor of Phenotype",
        "isPhenotypeOfStudy": "is Phenotype of Study",
        "isStudyOfPhenotype": "is Study of Phenotype",
        "isPhenotypeOfConceptSet": "is Phenotype of Concept Set",
        "isConceptSetOfPhenotype": "is Concept Set of Phenotype",
        "isMemberOfOrgUnit": "is Member of Organization Unit",
        "isOrgUnitOfPerson": "is Organization Unit of Person"
    }

def main():
    # Get user input
    type_choice = input("[E]ntity or [R]elationship Type? ").strip()
    schema_pattern = input("Enter the schema pattern (e.g., '[].y.z' or 'x.[].z' or 'x.y.[]'): ").strip()
    text_pattern = input("Enter the text pattern (use [type] for human-readable entity/relationship type, e.g., '[type] input' or 'input [type]'): ").strip()

    # Get types based on user choice
    types = get_types(type_choice)

    if not types:
        print("Invalid type choice. Please choose '[E]ntity' or '[R]elationship'.")
        return

    # Get type mapping
    type_mapping = get_type_mapping()

    # Generate schemas
    new_schemas = generate_schemas(types, schema_pattern, text_pattern, type_mapping)

    # Update JSON file
    json_file_path = 'en.json5'
    update_json_file(json_file_path, new_schemas)

    print(f"Generated and integrated {len(new_schemas)} new schemas into {json_file_path}")

if __name__ == "__main__":
    main()