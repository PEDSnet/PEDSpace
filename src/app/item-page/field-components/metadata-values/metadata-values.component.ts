import {
  AsyncPipe,
  NgClass,
  NgFor,
  NgIf,
  NgTemplateOutlet,
} from '@angular/common';
import {
  Component,
  HostBinding,
  Inject,
  Input,
  OnChanges,
  SimpleChanges,
  TemplateRef,
  ViewChild,
} from '@angular/core';
import { DomSanitizer } from '@angular/platform-browser';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import {
  APP_CONFIG,
  AppConfig,
} from '../../../../config/app-config.interface';
import { environment } from '../../../../environments/environment';
import { BrowseDefinition } from '../../../core/shared/browse-definition.model';
import { MetadataValue } from '../../../core/shared/metadata.models';
import { VALUE_LIST_BROWSE_DEFINITION } from '../../../core/shared/value-list-browse-definition.resource-type';
import { hasValue } from '../../../shared/empty.util';
import { MetadataFieldWrapperComponent } from '../../../shared/metadata-field-wrapper/metadata-field-wrapper.component';
import { MarkdownDirective } from '../../../shared/utils/markdown.directive';
import { ImageField } from '../../simple/field-components/specific-field/image-field';

/**
 * This component renders the configured 'values' into the ds-metadata-field-wrapper component.
 * It puts the given 'separator' between each two values.
 */
@Component({
  selector: 'ds-metadata-values',
  styleUrls: ['./metadata-values.component.scss'],
  templateUrl: './metadata-values.component.html',
  standalone: true,
  imports: [MetadataFieldWrapperComponent, NgFor, NgTemplateOutlet, NgIf, RouterLink, AsyncPipe, TranslateModule, MarkdownDirective, NgClass],
})
export class MetadataValuesComponent implements OnChanges {

  @ViewChild('isDQCheckRequirementTemplate') isDQCheckRequirementTemplate: TemplateRef<any>;

  // Add host binding to apply publisher class when isPublisher is true
  @HostBinding('class.publisher-content')
  get publisherContent() {
    return this.isPublisher;
  }

  constructor(
    @Inject(APP_CONFIG) private appConfig: AppConfig,
    private sanitizer: DomSanitizer,
  ) {
  }

  /**
   * The metadata values to display
   */
  @Input() mdValues: MetadataValue[];

  /**
   * The seperator used to split the metadata values (can contain HTML)
   */
  @Input() separator: string;

  /**
   * The label for this iteration of metadata values
   */
  @Input() label: string;

  /**
   * Whether the {@link MarkdownDirective} should be used to render these metadata values.
   * This will only have effect if {@link MarkdownConfig#enabled} is true.
   * Mathjax will only be rendered if {@link MarkdownConfig#mathjax} is true.
   */
  @Input() enableMarkdown = false;

  /**
   * Whether any valid HTTP(S) URL should be rendered as a link
   */
  @Input() urlRegex?;

  /**
   * This variable will be true if both {@link environment.markdown.enabled} and {@link enableMarkdown} are true.
   */
  renderMarkdown;

  /**
   * Input flag to apply special styling
   */
  @Input() isDQCheckRequirement?: boolean = false;

  @Input() browseDefinition?: BrowseDefinition;

  /**
   * Optional {@code ImageField} reference that represents an image to be displayed inline.
   */
  @Input() img?: ImageField;

  /**
   * Whether the metadata value should be rendered as a button
   */
  @Input() renderAsButton = false;

  @Input() fieldName: string;

  @Input() isPublisher = false;

  /**
   * The entity type of the metadata values
   */
  @Input() entityType: string;

  /**
   * Template string for inserting the metadata value into a sentence
   */
  @Input() sentenceTemplate?: string;

  /**
   * Parts of the sentenceTemplate split at [value]
   */
  sentenceTemplateParts: string[] | null = null;

  /**
   * Whether the metadata value should be rendered as a non-clickable badge
   */
  @Input() renderAsBadge = false;

  /**
   * Flag to apply citation styling to markdown content
   */
  @Input() applyCitationStyling = false;

  hasValue = hasValue;

  ngOnChanges(changes: SimpleChanges): void {
    this.renderMarkdown = !!this.appConfig.markdown.enabled && this.enableMarkdown;

    // Process the sentenceTemplate
    if (this.sentenceTemplate && this.sentenceTemplate !== '[value]') {
      // Split the sentence template and trim any extra spaces before/after parts
      this.sentenceTemplateParts = this.sentenceTemplate.split('[value]');
    } else {
      this.sentenceTemplateParts = null;
    }
  }

  /**
   * Does this metadata value have a configured link to a browse definition?
   */
  hasBrowseDefinition(): boolean {
    return hasValue(this.browseDefinition);
  }

  /**
   * Does this metadata value have a valid URL that should be rendered as a link?
   * @param value A MetadataValue being displayed
   */
  hasLink(value: MetadataValue): boolean {
    if (hasValue(this.urlRegex)) {
      const pattern = new RegExp(this.urlRegex);
      return pattern.test(value.value);
    }
    return false;
  }

  /**
   * Return a queryparams object for use in a link, with the key dependent on whether this browse
   * definition is metadata browse, or item browse
   * @param value the specific metadata value being linked
   */
  getQueryParams(value) {
    if (!this.browseDefinition) {
      return {};
    }
    const queryParams = { startsWith: value };
    // todo: should compare with type instead?
    // eslint-disable-next-line @typescript-eslint/no-unsafe-enum-comparison
    if (this.browseDefinition.getRenderType() === VALUE_LIST_BROWSE_DEFINITION.value) {
      return { value: value };
    }
    return queryParams;
  }

  /**
   * Get the last item in a string separated by '::'
   * @param value The string to split
   */
  getLastItem(value: string): string {
    const parts = value.split('::');
    return parts[parts.length - 1];
  }

  /**
   * Should the metadata value be rendered as a button?
   * @param mdValue The metadata value to check
   */
  shouldRenderAsButton(mdValue: MetadataValue): boolean {
    return this.renderAsButton && !this.renderAsBadge;
  }

  /**
   * Checks if the given link value is an internal link.
   * @param linkValue - The link value to check.
   * @returns True if the link value starts with the base URL defined in the environment configuration, false otherwise.
   */
  hasInternalLink(linkValue: string): boolean {
    return linkValue.startsWith(environment.ui.baseUrl);
  }

  getButtonClass(value: string): string {
    // Check if the field is in a specific metadata field
    if (this.fieldName) {
      // console.log('Field name:', this.fieldName);
      if (this.fieldName === 'local.dqcheck.outcomes') {
        return 'btn-response';
      } else if (this.fieldName === 'local.dqcheck.domain') {
        return 'btn-domain';
      } else if (this.fieldName === 'local.dqcheck.resultobs') {
        return 'btn-dq-observation';
      }
    }

    if (value.includes('Data Quality Category')) {
      return 'btn-dq-category';
    } else if (value.includes('Dataset Evaluation Strategy')) {
      return 'btn-dataset-eval-strategy';
    } else if (value.includes('Error Detection Approach')) {
      return 'btn-error-detection-approach';
    } else {
      return 'btn-outline-primary';
    }
  }

  /**
   * Should the metadata value be rendered as a badge?
   * @param mdValue The metadata value to check
   */
  shouldRenderAsBadge(mdValue: MetadataValue): boolean {
    return this.renderAsBadge;
  }

  /**
   * This method performs a validation and determines the target of the url.
   * @returns - Returns the target url.
   */
  getLinkAttributes(urlValue: string): { target: string, rel: string } {
    if (this.hasInternalLink(urlValue)) {
      return { target: '_self', rel: '' };
    } else {
      return { target: '_blank', rel: 'noopener noreferrer' };
    }
  }
}
