import { Config } from './config.interface';

interface AutosaveConfig extends Config {
  // list of metadata fields that trigger an autosave when edited; use '*' to trigger on any field
  metadata: string[];
  timer: number;
}

interface DuplicateDetectionConfig extends Config {
  alwaysShowSection: boolean;
}

interface TypeBindConfig extends Config {
  field: string;
}

interface IconsConfig extends Config {
  metadata: MetadataIconConfig[];
  authority: {
    confidence: ConfidenceIconConfig[];
  };
}

export interface MetadataIconConfig extends Config {
  name: string;
  style: string;
}

export interface ConfidenceIconConfig extends Config {
  value: any;
  style: string;
  icon: string;
}

export interface SubmissionConfig extends Config {
  autosave: AutosaveConfig;
  duplicateDetection: DuplicateDetectionConfig;
  typeBind: TypeBindConfig;
  icons: IconsConfig;
}
