import { NgIf, NgClass, AsyncPipe } from '@angular/common';
import { Component, Input, OnInit } from '@angular/core';
import { RouterModule } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
// import { Observable } from 'rxjs';
// import { map, tap } from 'rxjs/operators';
import { TypeBadgeComponent as BaseComponent } from 'src/app/shared/object-collection/shared/badges/type-badge/type-badge.component';
// import { BrowseDefinitionDataService } from 'src/app/core/browse/browse-definition-data.service';
// import { BrowseDefinition } from 'src/app/core/shared/browse-definition.model';
// import { getFirstCompletedRemoteData } from 'src/app/core/shared/operators';

@Component({
  selector: 'ds-verification-badge',
  styleUrls: ['./verification-badge.component.scss'],
  templateUrl: './verification-badge.component.html',
  standalone: true,
  imports: [NgIf, NgClass, TranslateModule, RouterModule, AsyncPipe],
})
export class VerificationBadgeComponent extends BaseComponent implements OnInit {
  @Input() nonClickable = true;

  _verificationStatus: string;
  // browseDefinition$: Observable<BrowseDefinition>;

  // constructor(private browseDefinitionDataService: BrowseDefinitionDataService) {
  //   super();
  // }

  ngOnInit() {
    this.setVerificationStatus();
    // this.initBrowseDefinition();
    // console.log('VerificationBadgeComponent ngOnInit');
    // console.log('this.object:', this.object);
    // console.log('this.verificationStatus:', this.verificationStatus);
  }

  private setVerificationStatus() {
    const status = this.object.firstMetadataValue('local.quality.status');
    this._verificationStatus = status ? `${status.toLowerCase().split(" ").join("")}.listelement.badge` : '';
    console.log('setVerificationStatus:', this._verificationStatus);
  }

  // private initBrowseDefinition() {
  //   const fields = ['local.quality.status'];
  //   this.browseDefinition$ = this.browseDefinitionDataService.findByFields(fields).pipe(
  //     getFirstCompletedRemoteData(),
  //     map((def) => def.payload),
  //     tap(browseDefinition => console.log('browseDefinition:', browseDefinition))
  //   );
  // }

  get verificationStatus(): string {
    return this._verificationStatus;
  }

  getBadgeClasses() {
    return {
      'badge-secondary': !this.verificationStatus.includes('verified') && !this.verificationStatus.includes('deprecated'),
      'badge-check': this.verificationStatus.includes('verified'),
      'badge-negative': this.verificationStatus.includes('deprecated'),
      'badge-study-specific': this.verificationStatus.includes('study')
    };
  }

  // getQueryParams(value: string) {
  //   console.log('getQueryParams input:', value);
  //   const actualValue = this.object?.firstMetadataValue('local.quality.status') || value;
  //   console.log('getQueryParams actualValue:', actualValue);
  //   return { value: actualValue };
  // }
}