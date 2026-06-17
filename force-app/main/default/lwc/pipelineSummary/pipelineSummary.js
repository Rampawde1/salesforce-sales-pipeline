import { LightningElement, wire } from 'lwc';
import getPipelineSummary from '@salesforce/apex/PipelineSummaryController.getPipelineSummary';
import getPipelineMetrics from '@salesforce/apex/PipelineSummaryController.getPipelineMetrics';

export default class PipelineSummary
    extends LightningElement {

    @wire(getPipelineSummary) pipeline;
    @wire(getPipelineMetrics)  metricsResult;

    // ── Metric card getters ──────────────────────
    get openCount() {
        return this.metricsResult?.data?.openCount
            ?? 0;
    }
    get formattedOpenTotal() {
        return this.formatINR(
            this.metricsResult?.data?.openTotal ?? 0
        );
    }
    get formattedWonQTD() {
        return this.formatINR(
            this.metricsResult?.data?.wonQTD ?? 0
        );
    }
    get winRate() {
        return Math.round(
            this.metricsResult?.data?.winRate ?? 0
        );
    }

    // ── Stage bar getter ─────────────────────────
    get stagesWithPct() {
        if (!this.pipeline.data) return [];
        const maxAmt = Math.max(
            ...this.pipeline.data.map(
                s => s.totalAmount
            ),
            1
        );
        return this.pipeline.data.map(s => ({
            ...s,
            pct: Math.round(
                (s.totalAmount / maxAmt) * 100
            ),
            barStyle:
                `width:${Math.round(
                    (s.totalAmount / maxAmt) * 100
                )}%;background:#534AB7`,
            formattedAmount: this.formatINR(
                s.totalAmount
            )
        }));
    }

    // ── Helper ───────────────────────────────────
    formatINR(amount) {
        if (!amount || amount === 0)
            return '₹0';
        if (amount >= 10000000)
            return '₹' +
                (amount/10000000).toFixed(1) +
                'Cr';
        if (amount >= 100000)
            return '₹' +
                (amount/100000).toFixed(1) +
                'L';
        return '₹' +
            amount.toLocaleString('en-IN');
    }

    renderedCallback() {
        const bars = this.template.querySelectorAll('.stage-bar');
        if (!bars) return;
        bars.forEach(bar => {
            const pct = bar.dataset.pct;
            if (pct) {
                bar.style.width = `${pct}%`;
                bar.style.background = '#534AB7';
            }
        });
    }
}