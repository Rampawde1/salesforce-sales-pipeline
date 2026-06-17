public with sharing class PipelineSummaryController {

    // ── Valid pipeline stages — only these show in the widget ─────
    private static final Set<String> OPEN_STAGES =
        new Set<String>{
            'Prospecting',
            'Qualification',
            'Needs Analysis',
            'Proposal/Price Quote',
            'Negotiation/Review'
        };

    private static final Map<String, Integer> STAGE_ORDER =
        new Map<String, Integer>{
            'Prospecting'      => 1,
            'Qualification'    => 2,
            'Needs Analysis'   => 3,
            'Proposal/Price Quote' => 4,
            'Negotiation/Review'      => 5
        };

    // ── getPipelineSummary ────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<StageWrapper> getPipelineSummary() {
        List<StageWrapper> result =
            new List<StageWrapper>();

        AggregateResult[] rows = [
            SELECT StageName  stage,
                   COUNT(Id)  cnt,
                   SUM(Amount) total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    StageName IN :OPEN_STAGES
            GROUP  BY StageName
        ];

        for (AggregateResult ar : rows) {
            result.add(new StageWrapper(
                (String)  ar.get('stage'),
                (Integer) ar.get('cnt'),
                (Decimal) ar.get('total')
            ));
        }

        // Sort in correct pipeline order (not alphabetical)
        result.sort(new StageComparator());
        return result;
    }

    // ── getPipelineMetrics ────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getPipelineMetrics() {
        Map<String, Decimal> metrics =
            new Map<String, Decimal>();

        // Total open pipeline — valid stages only
        AggregateResult openPipeline = [
            SELECT SUM(Amount) total,
                   COUNT(Id)   cnt
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    StageName IN :OPEN_STAGES
        ];
        metrics.put('openTotal',
            (Decimal) openPipeline.get('total') ?? 0);
        metrics.put('openCount',
            (Decimal) openPipeline.get('cnt') ?? 0);

        // Closed Won this quarter
        AggregateResult wonQTD = [
            SELECT SUM(Amount) total
            FROM   Opportunity
            WHERE  StageName = 'Closed Won'
            AND    CloseDate  = THIS_QUARTER
        ];
        metrics.put('wonQTD',
            (Decimal) wonQTD.get('total') ?? 0);

        // Win rate — won vs lost all time
        AggregateResult won = [
            SELECT COUNT(Id) cnt
            FROM   Opportunity
            WHERE  StageName = 'Closed Won'
        ];
        AggregateResult lost = [
            SELECT COUNT(Id) cnt
            FROM   Opportunity
            WHERE  StageName = 'Closed Lost'
        ];
        Integer wonCnt  = (Integer) won.get('cnt')  ?? 0;
        Integer lostCnt = (Integer) lost.get('cnt') ?? 0;
        Integer total   = wonCnt + lostCnt;
        metrics.put('winRate',
            total > 0
            ? ((Decimal) wonCnt / total * 100).setScale(1)
            : 0
        );

        return metrics;
    }

    // ── StageWrapper inner class ──────────────────────────────────
    public class StageWrapper {
        @AuraEnabled public String  stageName;
        @AuraEnabled public Integer dealCount;
        @AuraEnabled public Decimal totalAmount;

        public StageWrapper(
            String s, Integer c, Decimal t) {
            stageName   = s;
            dealCount   = c;
            totalAmount = t ?? 0;
        }
    }

    // ── StageComparator — sorts by pipeline order ─────────────────
    public class StageComparator
        implements Comparator<StageWrapper> {

        public Integer compare(
            StageWrapper a, StageWrapper b) {
            Integer oa = STAGE_ORDER.containsKey(a.stageName)
                         ? STAGE_ORDER.get(a.stageName) : 99;
            Integer ob = STAGE_ORDER.containsKey(b.stageName)
                         ? STAGE_ORDER.get(b.stageName) : 99;
            return oa - ob;
        }
    }
}