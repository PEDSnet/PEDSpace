import {
  Directive,
  ElementRef,
  Inject,
  InjectionToken,
  Input,
  OnDestroy,
  OnInit,
  SecurityContext,
} from '@angular/core';
import {
  DomSanitizer,
  SafeHtml,
} from '@angular/platform-browser';
import { Subject } from 'rxjs';
import {
  filter,
  take,
  takeUntil,
} from 'rxjs/operators';

import { environment } from '../../../environments/environment';
import { MathService } from '../../core/shared/math.service';
import { isEmpty } from '../empty.util';

const markdownItLoader = async () => {
  const markdownIt = await import('markdown-it');
  // const markdownItAttrs = await import('markdown-it-attrs');
  return markdownIt.default;
};
type LazyMarkdownIt = ReturnType<typeof markdownItLoader>;
const MARKDOWN_IT = new InjectionToken<LazyMarkdownIt>(
  'Lazily loaded MarkdownIt',
  { providedIn: 'root', factory: markdownItLoader },
);

@Directive({
  selector: '[dsMarkdown]',
  standalone: true,
})
export class MarkdownDirective implements OnInit, OnDestroy {

  @Input() dsMarkdown: string;
  @Input() pruneEmptyRows: boolean = true; // New Input for pruning
  private alive$ = new Subject<boolean>();

  el: HTMLElement;

  constructor(
    @Inject(MARKDOWN_IT) private markdownItLoader: LazyMarkdownIt,
    protected sanitizer: DomSanitizer,
    private mathService: MathService,
    private elementRef: ElementRef) {
    this.el = elementRef.nativeElement;
  }

  async ngOnInit() {
    await this.render(this.dsMarkdown);
  }

  async render(value: string, forcePreview = false): Promise<SafeHtml> {
    if (isEmpty(value) || (!environment.markdown.enabled && !forcePreview)) {
      this.el.innerHTML = value;
      return;
    }
    const MarkdownIt = await this.markdownItLoader;
    const md = new MarkdownIt({
      html: true,
      linkify: true,
      typographer: true, 
    });

    md.enable(['table']);

    // try {
    //   const markdownItAttrs = (await import('markdown-it-attrs')).default;
    //   md.use(markdownItAttrs);
    // } catch (error) {
    //   console.error('Failed to load markdown-it-attrs:', error);
    // }

    // Customize the link rendering to add target and rel attributes
    const defaultRender = md.renderer.rules.link_open || function(tokens, idx, options, env, self) {
      return self.renderToken(tokens, idx, options);
    };

    md.renderer.rules.link_open = (tokens, idx, options, env, self) => {
      const hrefIndex = tokens[idx].attrIndex('href');

      if (hrefIndex >= 0) {
        const hrefAttr = tokens[idx].attrs[hrefIndex];
        const hrefValue = hrefAttr[1];

        // Convert relative URLs to absolute URLs by prepending 'https://'
        const absoluteHref = this.makeAbsoluteUrl(hrefValue);
        hrefAttr[1] = absoluteHref;

        // Add target="_blank" and rel="noopener noreferrer"
        tokens[idx].attrPush(['target', '_blank']);
        tokens[idx].attrPush(['rel', 'noopener noreferrer']);
      }

      // Pass token to default renderer.
      return defaultRender(tokens, idx, options, env, self);
    };

    const html = md.render(value);
    const sanitizedHtml = this.sanitizer.sanitize(SecurityContext.HTML, html);

    let finalHtml = sanitizedHtml;

    if (this.pruneEmptyRows) {
      finalHtml = this.removeEmptyTableRows(sanitizedHtml);
    }

    this.el.innerHTML = `<div class="markdown-container table-responsive">${finalHtml}</div>`;

    if (environment.markdown.mathjax) {
      this.renderMathjax();
    }
  }

  /**
   * Convert relative URLs to absolute URLs by prepending 'https://' if no protocol is present.
   * Ensures that protocol-relative URLs (e.g., '//example.com') are correctly handled.
   * Only allows specific protocols for security reasons.
   */
  private makeAbsoluteUrl(url: string): string {
    if (!url) {
      return url;
    }

    const trimmedUrl = url.trim();

    // Regular expression to test for allowed protocols
    const allowedProtocols = /^(https?:|mailto:|tel:)/i;

    if (allowedProtocols.test(trimmedUrl)) {
      // URL already has an allowed protocol (e.g., http://, https://, mailto:, tel:)
      return trimmedUrl;
    }

    if (trimmedUrl.startsWith('//')) {
      // Protocol-relative URL; prepend 'https:'
      return `https:${trimmedUrl}`;
    }

    if (/^[a-zA-Z][a-zA-Z\d+\-.]*:/.test(trimmedUrl)) {
      // URL has an unallowed or unsupported protocol; consider sanitizing or rejecting
      // For now, return as is without modification
      return trimmedUrl;
    }

    // URL lacks a protocol; assume 'https://' and prepend
    return `https://${trimmedUrl}`;
  }

  /**
   * Parses the HTML string, removes any empty table rows, and returns the cleaned HTML string.
   * @param html The sanitized HTML string to process.
   * @returns The cleaned HTML string with empty table rows removed.
   */
  private removeEmptyTableRows(html: string): string {
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');

    const tables = doc.querySelectorAll('table');

    tables.forEach(table => {
      const rows = table.querySelectorAll('tr');

      rows.forEach(row => {
        const cells = row.querySelectorAll('th, td');
        let isEmpty = true;

        cells.forEach(cell => {
          const text = cell.textContent?.trim().replace(/\u00a0/g, '');
          if (text && text !== '') {
            isEmpty = false;
          }
        });

        if (isEmpty) {
          row.remove();
        }
      });
    });

    return doc.body.innerHTML;
  }

  private renderMathjax() {
    this.mathService.ready().pipe(
      filter((ready) => ready),
      take(1),
      takeUntil(this.alive$),
    ).subscribe(() => {
      this.mathService.render(this.el);
    });
  }

  ngOnDestroy() {
    this.alive$.next(false);
    this.alive$.complete();
  }
}
