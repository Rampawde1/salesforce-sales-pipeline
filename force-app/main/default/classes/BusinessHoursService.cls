public class BusinessHoursService {
    @InvocableMethod(label='Add Business Hours' description='Calculates target DateTime by adding hours using a specific Business Hours record.')
    public static List<DateTime> addHours(List<BusinessHoursInput> inputs) {
        List<DateTime> results = new List<DateTime>();
        for (BusinessHoursInput input : inputs) {
            // Convert hours to milliseconds (Salesforce BusinessHours class expects milliseconds)
            Long msecs = (Long)(input.hoursToAdd * 60 * 60 * 1000);
            DateTime targetTime = BusinessHours.add(input.businessHoursId, input.startDate, msecs);
            results.add(targetTime);
        }
        return results;
    }

    public class BusinessHoursInput {
        @InvocableVariable(required=true label='Business Hours ID')
        public Id businessHoursId;

        @InvocableVariable(required=true label='Start Date Time')
        public DateTime startDate;

        @InvocableVariable(required=true label='Hours to Add')
        public Decimal hoursToAdd;
    }
}