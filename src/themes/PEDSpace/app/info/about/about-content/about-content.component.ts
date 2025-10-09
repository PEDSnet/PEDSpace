import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { RouterModule } from '@angular/router';

@Component({
  selector: 'ds-about-content',
  templateUrl: './about-content.component.html',
  styleUrls: ['./about-content.component.scss'],
  standalone: true,
  imports: [CommonModule, RouterModule],
})
/**
 * Component displaying the content of the PEDSpace Knowledge Bank About page
 */
export class AboutContentComponent {
  // Component logic can be added here if needed in the future
}
