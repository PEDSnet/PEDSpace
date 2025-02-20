import { Component } from '@angular/core';

import { CommunityPageSubCommunityListComponent as BaseComponent } from '../../../../../app/community-page/sub-community-list/community-page-sub-community-list.component';

@Component({
  selector: 'ds-base-community-page-sub-community-list',
  // styleUrls: ['./community-page-sub-community-list.component.scss'],
  styleUrls: ['../../../../../app/community-page/sub-community-list/community-page-sub-community-list.component.scss'],
  // templateUrl: './community-page-sub-community-list.component.html',
  templateUrl: '../../../../../app/community-page/sub-community-list/community-page-sub-community-list.component.html',
  standalone: true,
})
export class CommunityPageSubCommunityListComponent extends BaseComponent {}
