import {
  AsyncPipe,
  NgForOf,
  NgIf,
  NgSwitch,
  NgSwitchCase,
  NgSwitchDefault,
} from '@angular/common';
import {
  ChangeDetectorRef,
  Component,
  Inject,
} from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import {
  BehaviorSubject,
  combineLatest,
  combineLatest as observableCombineLatest,
  Observable,
  Subscription,
} from 'rxjs';
import {
  distinctUntilChanged,
  filter,
  map,
  mergeMap,
  switchMap,
  tap,
} from 'rxjs/operators';
import { WorkspaceitemSectionUploadObject } from 'src/app/core/submission/models/workspaceitem-section-upload.model';

import { DSONameService } from '../../../core/breadcrumbs/dso-name.service';
import { AccessConditionOption } from '../../../core/config/models/config-access-condition-option.model';
import { SubmissionFormsModel } from '../../../core/config/models/config-submission-forms.model';
import { SubmissionUploadsModel } from '../../../core/config/models/config-submission-uploads.model';
import { SubmissionUploadsConfigDataService } from '../../../core/config/submission-uploads-config-data.service';
import { CollectionDataService } from '../../../core/data/collection-data.service';
import { RemoteData } from '../../../core/data/remote-data';
import { GroupDataService } from '../../../core/eperson/group-data.service';
import { Group } from '../../../core/eperson/models/group.model';
import { ResourcePolicyDataService } from '../../../core/resource-policy/resource-policy-data.service';
import { Collection } from '../../../core/shared/collection.model';
import { getFirstSucceededRemoteData } from '../../../core/shared/operators';
import { AlertComponent } from '../../../shared/alert/alert.component';
import { AlertType } from '../../../shared/alert/alert-type';
import {
  hasValue,
  isNotEmpty,
  isNotUndefined,
  isUndefined,
} from '../../../shared/empty.util';
import { followLink } from '../../../shared/utils/follow-link-config.model';
import { SubmissionObjectEntry } from '../../objects/submission-objects.reducer';
import { SubmissionService } from '../../submission.service';
import { SectionModelComponent } from '../models/section.model';
import { SectionDataObject } from '../models/section-data.model';
import { SectionsService } from '../sections.service';
import { SubmissionSectionUploadAccessConditionsComponent } from './accessConditions/submission-section-upload-access-conditions.component';
import { ThemedSubmissionSectionUploadFileComponent } from './file/themed-section-upload-file.component';
import { SectionUploadService } from './section-upload.service';

export const POLICY_DEFAULT_NO_LIST = 1; // Banner1
export const POLICY_DEFAULT_WITH_LIST = 2; // Banner2

export interface AccessConditionGroupsMapEntry {
  accessCondition: string;
  groups: Group[];
}

/**
 * This component represents a section that contains submission's bitstreams
 */
@Component({
  selector: 'ds-submission-section-upload',
  styleUrls: ['./section-upload.component.scss'],
  templateUrl: './section-upload.component.html',
  imports: [
    ThemedSubmissionSectionUploadFileComponent,
    SubmissionSectionUploadAccessConditionsComponent,
    NgIf,
    AlertComponent,
    TranslateModule,
    NgForOf,
    AsyncPipe,
    NgSwitch,
    NgSwitchCase,
    NgSwitchDefault,
  ],
  standalone: true,
})
export class SubmissionSectionUploadComponent extends SectionModelComponent {

  /**
   * The AlertType enumeration
   * @type {AlertType}
   */
  public AlertTypeEnum = AlertType;

  /**
   * The uuid of primary bitstream file
   * @type {Array}
   */
  public primaryBitstreamUUID: string | null = null;

  /**
   * The file list
   * @type {Array}
   */
  public fileList: any[] = [];

  /**
   * The array containing the name of the files
   * @type {Array}
   */
  public fileNames: string[] = [];

  /**
   * The collection name this submission belonging to
   * @type {string}
   */
  public collectionName: string;

  /**
   * Default access conditions of this collection
   * @type {Array}
   */
  public collectionDefaultAccessConditions: any[] = [];

  /**
   * Define if collection access conditions policy type :
   * POLICY_DEFAULT_NO_LIST : is not possible to define additional access group/s for the single file
   * POLICY_DEFAULT_WITH_LIST : is possible to define additional access group/s for the single file
   * @type {number}
   */
  public collectionPolicyType: number;

  /**
   * The configuration for the bitstream's metadata form
   */
  public configMetadataForm$: Observable<SubmissionFormsModel>;

  /**
   * List of available access conditions that could be set to files
   */
  public availableAccessConditionOptions: AccessConditionOption[];  // List of accessConditions that an user can select

  /**
   * Is the upload required
   * @type {boolean}
   */
  public required$ = new BehaviorSubject<boolean>(true);

  /**
   * The submission definition name to determine which info message to show
   * @type {string}
   */
  public submissionDefinition: string | null = null;

  /**
   * Array to track all subscriptions and unsubscribe them onDestroy
   * @type {Array}
   */
  protected subs: Subscription[] = [];

  /**
   * Initialize instance variables
   *
   * @param {SectionUploadService} bitstreamService
   * @param {ChangeDetectorRef} changeDetectorRef
   * @param {CollectionDataService} collectionDataService
   * @param {GroupDataService} groupService
   * @param {ResourcePolicyDataService} resourcePolicyService
   * @param {SectionsService} sectionService
   * @param {SubmissionService} submissionService
   * @param {SubmissionUploadsConfigDataService} uploadsConfigService
   * @param {SectionDataObject} injectedSectionData
   * @param {string} injectedSubmissionId
   */
  constructor(private bitstreamService: SectionUploadService,
              private changeDetectorRef: ChangeDetectorRef,
              private collectionDataService: CollectionDataService,
              private groupService: GroupDataService,
              private resourcePolicyService: ResourcePolicyDataService,
              protected sectionService: SectionsService,
              private submissionService: SubmissionService,
              private uploadsConfigService: SubmissionUploadsConfigDataService,
              public dsoNameService: DSONameService,
              @Inject('sectionDataProvider') public injectedSectionData: SectionDataObject,
              @Inject('submissionIdProvider') public injectedSubmissionId: string) {
    super(undefined, injectedSectionData, injectedSubmissionId);
  }

  /**
   * Initialize all instance variables and retrieve collection default access conditions
   */
  onSectionInit() {
    const config$ = this.uploadsConfigService.findByHref(this.sectionData.config, true, false, followLink('metadata')).pipe(
      getFirstSucceededRemoteData(),
      map((config) => config.payload));

    // retrieve configuration for the bitstream's metadata form
    this.configMetadataForm$ = config$.pipe(
      switchMap((config: SubmissionUploadsModel) =>
        config.metadata.pipe(
          getFirstSucceededRemoteData(),
          map((remoteData: RemoteData<SubmissionFormsModel>) => remoteData.payload),
        ),
      ));

    // Add subscription to check the actual submission object from the service
    this.subs.push(
      this.submissionService.getSubmissionObject(this.submissionId).pipe(
        tap((fullSubmissionObject) => {
          if (fullSubmissionObject && typeof fullSubmissionObject === 'object') {
            if ('definition' in fullSubmissionObject) {
              this.submissionDefinition = fullSubmissionObject.definition;
              this.changeDetectorRef.detectChanges();
            }
          }
        }),
      ).subscribe(),
    );

    this.subs.push(
      this.submissionService.getSubmissionObject(this.submissionId).pipe(
        filter((submissionObject: SubmissionObjectEntry) => isNotUndefined(submissionObject) && !submissionObject.isLoading),
        filter((submissionObject: SubmissionObjectEntry) => isUndefined(this.collectionId) || this.collectionId !== submissionObject.collection),
        tap((submissionObject: SubmissionObjectEntry) => this.collectionId = submissionObject.collection),
        mergeMap((submissionObject: SubmissionObjectEntry) => this.collectionDataService.findById(submissionObject.collection)),
        filter((rd: RemoteData<Collection>) => isNotUndefined((rd.payload))),
        tap((collectionRemoteData: RemoteData<Collection>) => this.collectionName = this.dsoNameService.getName(collectionRemoteData.payload)),
        // TODO review this part when https://github.com/DSpace/dspace-angular/issues/575 is resolved
        /*        mergeMap((collectionRemoteData: RemoteData<Collection>) => {
          return this.resourcePolicyService.findByHref(
            (collectionRemoteData.payload as any)._links.defaultAccessConditions.href
          );
        }),
        filter((defaultAccessConditionsRemoteData: RemoteData<ResourcePolicy>) =>
          defaultAccessConditionsRemoteData.hasSucceeded),
        tap((defaultAccessConditionsRemoteData: RemoteData<ResourcePolicy>) => {
          if (isNotEmpty(defaultAccessConditionsRemoteData.payload)) {
            this.collectionDefaultAccessConditions = Array.isArray(defaultAccessConditionsRemoteData.payload)
              ? defaultAccessConditionsRemoteData.payload : [defaultAccessConditionsRemoteData.payload];
          }
        }),*/
        mergeMap(() => config$),
      ).subscribe((config: SubmissionUploadsModel) => {
        this.required$.next(config.required);
        this.availableAccessConditionOptions = isNotEmpty(config.accessConditionOptions) ? config.accessConditionOptions : [];
        this.collectionPolicyType = this.availableAccessConditionOptions.length > 0
          ? POLICY_DEFAULT_WITH_LIST
          : POLICY_DEFAULT_NO_LIST;
        this.changeDetectorRef.detectChanges();
      }),

      // retrieve submission's bitstream data from state
      combineLatest([
        this.configMetadataForm$,
        this.bitstreamService.getUploadedFilesData(this.submissionId, this.sectionData.id),
      ]).pipe(
        filter(([configMetadataForm, sectionUploadObject]: [SubmissionFormsModel, WorkspaceitemSectionUploadObject]) => {
          return isNotEmpty(configMetadataForm) && isNotEmpty(sectionUploadObject);
        }),
        distinctUntilChanged(),
      ).subscribe(([configMetadataForm, { primary, files }]: [SubmissionFormsModel, WorkspaceitemSectionUploadObject]) => {
        this.primaryBitstreamUUID = primary;
        this.fileList = files;
        this.fileNames = Array.from(files, file => this.getFileName(configMetadataForm, file));
        this.changeDetectorRef.detectChanges();
      }),
    );
  }

  /**
   * Return file name from metadata
   *
   * @param configMetadataForm
   *    the bitstream's form configuration
   * @param fileData
   *    the file metadata
   */
  private getFileName(configMetadataForm: SubmissionFormsModel, fileData: any): string {
    const metadataName: string = configMetadataForm.rows[0].fields[0].selectableMetadata[0].metadata;
    let title: string;
    if (isNotEmpty(fileData.metadata) && isNotEmpty(fileData.metadata[metadataName])) {
      title = fileData.metadata[metadataName][0].display;
    } else {
      title = fileData.uuid;
    }

    return title;
  }

  /**
   * Get section status
   *
   * @return Observable<boolean>
   *     the section status
   */
  protected getSectionStatus(): Observable<boolean> {
    // if not mandatory, always true
    // if mandatory, at least one file is required
    return observableCombineLatest(this.required$,
      this.bitstreamService.getUploadedFileList(this.submissionId, this.sectionData.id),
      (required,fileList: any[]) => {
        return (!required || (isNotUndefined(fileList) && fileList.length > 0));
      });
  }

  /**
   * Method provided by Angular. Invoked when the instance is destroyed.
   */
  onSectionDestroy() {
    this.subs
      .filter((subscription) => hasValue(subscription))
      .forEach((subscription) => subscription.unsubscribe());
  }

}
