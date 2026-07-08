export interface Subdomain {
  label: string;
  href: string;
}

/**
 * Maps a DSpace community UUID to the immediate children shown in the
 * Browse Subdomains dropdown.
 *
 * Keys   — community UUID extracted from /communities/{uuid}
 * Values — child entries using Angular router paths (relative to the app's
 *          base href), so they work identically across all environments.
 */
export const COMMUNITY_SUBDOMAINS: Record<string, Subdomain[]> = {

  // ── Data Quality Modules ─────────────────────────────────────────────────
  '57fd85d3-0b50-4239-8f05-8db5e0e65a6a': [
    { label: 'Cohort Fitness',                     href: '/communities/dc11bca6-d7df-45d0-878a-a47934aee648' },
    { label: 'Cohort Identification',              href: '/communities/0afb13f9-1fdd-41a9-ae3f-0658068e28ba' },
    { label: 'Concept Set Testing',                href: '/communities/eb727e7d-be51-4b02-b556-33998b016e9d' },
    { label: 'Data Conformance',                   href: '/communities/0d626026-69b4-4388-9234-04e3ad512079' },
    { label: 'Dataset Fitness',                    href: '/communities/f640d53d-5f2a-476f-ab06-42274668de2f' },
    { label: 'Variable Testing',                   href: '/communities/4a439fd8-80f7-4b60-bc33-f029f0edb1af' },
    { label: 'Network-Level Data Quality Modules', href: '/collections/00e66074-9449-4d3f-bca3-ecf347aa8383' },
  ],

  // ── Cohort Fitness ───────────────────────────────────────────────────────
  'dc11bca6-d7df-45d0-878a-a47934aee648': [
    { label: 'Clinical Data Values and Ranges', href: '/collections/bfee60b0-e7fe-4d83-b98d-7d9541c179c3' },
    { label: 'Expected Facts Present',           href: '/collections/dbe85223-676c-4024-aef6-7692de0576e5' },
    { label: 'Patient Event Sequencing',         href: '/collections/85838459-479a-461c-ad15-786f18cc8536' },
    { label: 'Patient Facts',                    href: '/collections/69c64223-f9ce-4a80-bf1a-11f27a7fc794' },
    { label: 'Patient Records Consistency',      href: '/collections/e774e9ea-d81b-4bc4-badc-e2b4a8059239' },
  ],

  // ── Cohort Identification ────────────────────────────────────────────────
  '0afb13f9-1fdd-41a9-ae3f-0658068e28ba': [
    { label: 'Cohort Attrition',                  href: '/collections/288ffd15-787e-4f20-8710-2851d1f3f997' },
    { label: 'Sensitivity to Selection Criteria', href: '/collections/4759746d-fbdc-4478-bea0-46161c9bc985' },
  ],

  // ── Concept Set Testing ──────────────────────────────────────────────────
  'eb727e7d-be51-4b02-b556-33998b016e9d': [
    { label: 'Concept Set Distributions',       href: '/collections/89107ca4-cfb8-405f-8239-bdcb958f65d5' },
    { label: 'Source and Concept Vocabularies', href: '/collections/664bce26-69a1-445e-aa1a-c8eb1d6ba95a' },
    { label: 'Unmapped Concepts',               href: '/collections/0c1d9d18-bc89-4576-a7dc-df4e5ef4877d' },
  ],

  // ── Data Conformance ─────────────────────────────────────────────────────
  '0d626026-69b4-4388-9234-04e3ad512079': [
    { label: 'Clinical Metadata',      href: '/collections/bf06e83e-3197-483f-89e6-56c8893335e6' },
    { label: 'Duplicate Record Check', href: '/collections/34f2f1cd-4305-4e42-bfec-6493a43d873e' },
  ],

  // ── Dataset Fitness ──────────────────────────────────────────────────────
  'f640d53d-5f2a-476f-ab06-42274668de2f': [
    { label: 'Clinical Events and Specialty Agreements', href: '/collections/fb1cee7a-385b-49d1-81c6-63816e97a133' },
    { label: 'Date Sequencing',                          href: '/collections/e173f1df-0318-40b3-9223-2bab47ee0b86' },
    { label: 'Visit Clinical Data Agreement',            href: '/collections/c61d26ef-8797-4cb9-8886-2f7068f3f14a' },
  ],

  // ── Variable Testing ─────────────────────────────────────────────────────
  '4a439fd8-80f7-4b60-bc33-f029f0edb1af': [
    { label: 'Categorical Variable Distribution',   href: '/collections/37176c0a-7147-41ad-8ea8-7c997544a1f4' },
    { label: 'Expected Variables Present',          href: '/collections/9d9e267c-f506-4b67-95bb-e7c6c6a91835' },
    { label: 'Quantitative Variable Distributions', href: '/collections/4f367080-0369-450a-806c-c5358a786684' },
  ],

  // ── PEDSnet Projects & Studies ───────────────────────────────────────────
  '92eba3a4-d7d3-43bd-b3f9-0f84c68c08f6': [
    { label: 'PEDSnet Projects',
      href: '/collections/b79d302e-1157-4d32-83ac-32d4411ac3b6' },
    { label: 'National Evaluation System for Health Technology Coordinating Center (NESTcc) Program',
      href: '/collections/d65d5d72-51c6-4e78-88f3-08a790c854c8' },
    { label: 'PCORnet® Designated Studies',
      href: '/collections/6c8dedcf-c919-45f8-882b-e92de1bbcb55' },
    { label: 'PEDSnet Infrastructure',
      href: '/collections/f23ec374-e99b-4de4-9c83-8cc9b7618dbd' },
    { label: 'PEDSnet Nephrology Research Program',
      href: '/collections/fde608a7-1771-4bab-85de-eb23c2810732' },
    { label: 'PEDSnet Publications',
      href: '/collections/61d66a9f-af60-4522-bab8-f2c14cdfb9a1' },
    { label: 'PEDSnet Scholars Program',
      href: '/collections/9170ce17-76c5-4c82-b9b2-fd1f2e07c6fb' },
    { label: 'Preserving Kidney Function in Children with Chronic Kidney Disease (PRESERVE) Project',
      href: '/collections/c9e10fb0-3b40-483a-a1c0-97fff3772e6e' },
    { label: 'Researching COVID to Enhance Recovery (RECOVER) Project',
      href: '/collections/616988d8-733d-4931-bd6b-dd22212d9aa8' },
  ],

  // ── PEDSnet Resources ────────────────────────────────────────────────────
  'dd8cbefd-bc37-476c-a383-7c9fe413743f': [
    { label: 'Data Architecture',                  href: '/collections/646ebb9d-ec74-4902-b654-e4fbcf0988f1' },
    { label: 'Documentation & Learning Materials', href: '/collections/0b3bab26-df86-4f72-b571-a11967535e1e' },
    { label: 'Electronic Resources',               href: '/collections/6e1c7021-5fb5-4665-b296-60e5c17f11b8' },
    { label: 'PEDSnet Sites',                      href: '/collections/d8438a5d-befd-4739-9553-a12ee82a7f55' },
    { label: 'Reusable Code',                      href: '/collections/1ebbc2c6-32a3-40fb-9ac4-0d5eee7b7518' },
  ],

  // ── Variable Dictionary ──────────────────────────────────────────────────
  '20a103f9-6690-4f17-a523-9abc168f0801': [
    { label: 'Algorithms',   href: '/communities/5a20af3d-06f0-42d2-8d01-0a17f3ecf27b' },
    { label: 'Concept Sets', href: '/communities/b6f6e99f-d383-4fb2-952d-daec4cadfc9c' },
  ],

  // ── Algorithms ───────────────────────────────────────────────────────────
  '5a20af3d-06f0-42d2-8d01-0a17f3ecf27b': [
    { label: 'Cardiovascular Algorithms',
      href: '/collections/df91146d-37ad-4575-a933-a1709fc3af70' },
    { label: 'Congenital, Hereditary, and Neonatal Disease and Abnormality Algorithms',
      href: '/collections/f15aef83-4305-437e-a1cf-d1a0d35cccaa' },
    { label: 'Digestive System Algorithms',
      href: '/collections/a8ced3c4-0de0-4908-bab1-0d75f03b1a78' },
    { label: 'Endocrine System Algorithms',
      href: '/collections/6eda4e9a-571f-475d-9dad-f68a390b4ef2' },
    { label: 'Eye Condition Algorithms',
      href: '/collections/9bc8513d-e708-4e35-a78c-446c3d3a079c' },
    { label: 'Hemic and Lymphatic Algorithms',
      href: '/collections/33b69534-26b4-4dc9-85e4-b90da6136494' },
    { label: 'Immune System Algorithms',
      href: '/collections/8e7648d7-bcfc-4799-baba-c34bc540b367' },
    { label: 'Infection Algorithms',
      href: '/collections/0390ab14-71c5-45a4-a8a0-cbd6e1cfde25' },
    { label: 'Musculoskeletal Algorithms',
      href: '/collections/a7e6c1ee-343d-4e49-bfb2-4935513e9965' },
    { label: 'Neoplasm Algorithms',
      href: '/collections/68fd2509-d41c-474b-89bf-01d4a22a4106' },
    { label: 'Nervous System Algorithms',
      href: '/collections/59e5ab52-225e-4860-9325-473aa59c169b' },
    { label: 'Nutritional and Metabolic Algorithms',
      href: '/collections/1c9fa8a1-6234-45b8-9d6d-47a0f6d51e2e' },
    { label: 'Otorhinolaryngologic Algorithms',
      href: '/collections/7d94227a-a016-4d8a-af9b-3d7a0697edf6' },
    { label: 'Pathological Conditions, Signs and Symptoms Algorithms',
      href: '/collections/2a1b3862-c777-4103-a057-bb30c6d01ed2' },
    { label: 'Population Characteristics: Socioeconomic and Environmental Impact Algorithms',
      href: '/collections/bb7f3fd4-d85c-406d-990d-f94e42b2f9bc' },
    { label: 'Psychiatric and Psychological Algorithms',
      href: '/collections/1792d541-edcc-4c17-97a1-380544ed6b2d' },
    { label: 'Respiratory Tract Algorithms',
      href: '/collections/d5de877d-5ad5-4f6b-a449-cd9fb3a3b5ed' },
    { label: 'Skin and Connective Tissue Algorithms',
      href: '/collections/2beb65ac-7d36-4365-a0ce-819cf7520a03' },
    { label: 'Stomatognathic Algorithms',
      href: '/collections/7df8753d-b25f-4383-9969-fc3777453e54' },
    { label: 'Urogenital Algorithms',
      href: '/collections/6a8268bd-1f76-452d-9de9-f3fa4b1653a4' },
  ],

  // ── Concept Sets ─────────────────────────────────────────────────────────
  'b6f6e99f-d383-4fb2-952d-daec4cadfc9c': [
    { label: 'Device Concept Sets',
      href: '/collections/f8768768-67c8-436b-b7eb-71ccc7251899' },
    { label: 'Diagnosis Concept Sets',
      href: '/collections/b8fcddb4-228e-4409-aa44-3b04341e92b6' },
    { label: 'Environmental and Socioeconomic Variable Concept Sets',
      href: '/collections/c1ce3502-0745-43c2-a8ff-2c259bb6077d' },
    { label: 'Laboratory Result Concept Sets',
      href: '/collections/118a1a8e-c914-4e29-8669-b7a82cc0a8b8' },
    { label: 'Medication Concept Sets',
      href: '/collections/cc407980-d7f5-4cb2-a94a-aca8c70ebf57' },
    { label: 'Physiological Measurement Concept Sets',
      href: '/collections/236af2cb-def7-40f3-9b61-afd552234160' },
    { label: 'Procedure Concept Sets',
      href: '/collections/fefb676f-fe83-40dc-b919-bc73e03a70ac' },
    { label: 'Visit Concept Sets',
      href: '/collections/7793c748-ceec-46c5-a067-0a976e2fd07f' },
  ],
};