import { Component } from '@angular/core';

import { CommunityPageSubCollectionListComponent as BaseComponent } from '../../../../../app/community-page/sub-collection-list/community-page-sub-collection-list.component';

@Component({
  selector: 'ds-base-community-page-sub-collection-list',
  // styleUrls: ['./community-page-sub-collection-list.component.scss'],
  styleUrls: ['../../../../../app/community-page/sub-collection-list/community-page-sub-collection-list.component.scss'],
  // templateUrl: './community-page-sub-collection-list.component.html',
  templateUrl: '../../../../../app/community-page/sub-collection-list/community-page-sub-collection-list.component.html',
  standalone: true,
})
export class CommunityPageSubCollectionListComponent extends BaseComponent {}
