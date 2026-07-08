import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { environment } from 'src/environments/environment';
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

@Component({
  selector: 'ds-themed-home-news',
  styleUrls: ['./home-news.component.scss'],
  templateUrl: './home-news.component.html',
  standalone: true,
  imports: [CommonModule],
})
export class HomeNewsComponent extends BaseComponent implements OnInit {
  isProduction: boolean = environment.production;
  ipAddressMatch = false;
  showMessageAtAll: boolean = false;

  private targetIpAddress = 'pedsnet.org';

  ngOnInit(): void {
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
  }
}
