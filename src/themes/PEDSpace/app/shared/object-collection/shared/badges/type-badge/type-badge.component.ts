import {
  AsyncPipe,
  NgIf,
  NgClass
} from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { RouterModule } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Observable } from 'rxjs';
import { map, tap } from 'rxjs/operators';
import { TypeBadgeComponent as BaseComponent } from 'src/app/shared/object-collection/shared/badges/type-badge/type-badge.component';
import { BrowseDefinitionDataService } from 'src/app/core/browse/browse-definition-data.service';
import { BrowseDefinition } from 'src/app/core/shared/browse-definition.model';
import { getFirstCompletedRemoteData } from 'src/app/core/shared/operators';
import { ResourceType } from 'src/app/core/shared/resource-type';

@Component({
  selector: 'ds-themed-type-badge',
  styleUrls: ['./type-badge.component.scss'],
  templateUrl: './type-badge.component.html',
  standalone: true,
  imports: [NgIf, NgClass, TranslateModule, RouterModule, AsyncPipe],
})
export class TypeBadgeComponent extends BaseComponent implements OnInit {
  browseDefinition$: Observable<BrowseDefinition>;

  constructor(private browseDefinitionDataService: BrowseDefinitionDataService) {
    super();
  }

  ngOnInit() {
    console.log('TypeBadgeComponent ngOnInit');
    console.log('this.object:', this.object);
    console.log('this.object.type:', this.object?.type);
    console.log('this.typeMessage:', this.typeMessage);
    this.initBrowseDefinition();
  }

  private initBrowseDefinition() {
    const fields = ['dspace.entity.type'];
    this.browseDefinition$ = this.browseDefinitionDataService.findByFields(fields).pipe(
      getFirstCompletedRemoteData(),
      map((def) => def.payload),
      tap(browseDefinition => console.log('browseDefinition:', browseDefinition))
    );
  }

  getDisplayValue(value: string): string {
    console.log('getDisplayValue input:', value);
    const displayValue = value === 'ConceptSet' ? 'Concept Set' : value;
    console.log('getDisplayValue output:', displayValue);
    return displayValue;
  }

  getQueryParams(value: string) {
    console.log('getQueryParams input:', value);
    const actualValue = this.object?.firstMetadataValue('dspace.entity.type') || value;
    console.log('getQueryParams actualValue:', actualValue);
    return { value: actualValue };
  }

  getTypeClass(): string {
    const objectType = this.object?.firstMetadataValue('dspace.entity.type') || this.typeMessage;
    console.log('getTypeClass objectType:', objectType);
    switch (objectType) {
      case 'ConceptSet':
        return 'badge-conceptset';
      case 'DQCheck':
        return 'badge-dqcheck';
      case 'Documentation':
        return 'badge-documentation';
      case 'Study':
        return 'badge-study';
      default:
        return 'badge-default';
    }
  }
}