import { CommonModule } from '@angular/common';
import {
  Component,
  OnInit,
} from '@angular/core';
import { ThemedHomeNewsComponent } from 'src/app/home-page/home-news/themed-home-news.component';
import { environment } from 'src/environments/environment';

// eslint-disable-next-line dspace-angular-ts/themed-component-usages
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

@Component({
  selector: 'ds-themed-home-news',
  // styleUrls: ['./home-news.component.scss'],
  styleUrls: ['../../../../../app/home-page/home-news/home-news.component.scss'],
  // templateUrl: './home-news.component.html'
  templateUrl: '../../../../../app/home-page/home-news/home-news.component.html',
  standalone: true,
  imports: [BaseComponent, CommonModule, ThemedHomeNewsComponent],
})
export class HomeNewsComponent extends BaseComponent implements OnInit {
  isProduction: boolean = environment.production;
  ipAddressMatch = false; // For storing if IP matches
  showDevOnProdMessage = false;

  private targetIpAddress = 'pedsnetapps.chop.edu';

  constructor() {
    super();
  }

  ngOnInit(): void {
    // Check if the environment's host matches the target IP
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
  }
}
