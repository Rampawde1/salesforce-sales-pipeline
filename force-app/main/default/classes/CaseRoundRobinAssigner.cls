public class CaseRoundRobinAssigner {

    @InvocableMethod(label='Assign Case via Round Robin' 
                     description='Assigns case to next agent in queue using round robin')
    public static List<Result> assignCase(List<Request> requests) {
        
        List<Result> results = new List<Result>();
        
        // 1. Collect all queue names from the bulk request
        Set<String> queueNames = new Set<String>();
        for (Request req : requests) {
            if (String.isNotBlank(req.queueName)) {
                queueNames.add(req.queueName);
            }
        }
        
        // 2. Bulk query Group Members grouped by Queue DeveloperName
        Map<String, List<Id>> queueToMembersMap = new Map<String, List<Id>>();
        for (GroupMember gm : [
            SELECT UserOrGroupId, Group.DeveloperName 
            FROM GroupMember 
            WHERE Group.DeveloperName IN :queueNames
            AND Group.Type = 'Queue'
            ORDER BY UserOrGroupId ASC
        ]) {
            if (!queueToMembersMap.containsKey(gm.Group.DeveloperName)) {
                queueToMembersMap.put(gm.Group.DeveloperName, new List<Id>());
            }
            queueToMembersMap.get(gm.Group.DeveloperName).add(gm.UserOrGroupId);
        }
        
        // 3. Bulk query Trackers and map them
        Map<String, Queue_Tracker__c> trackerMap = new Map<String, Queue_Tracker__c>();
        for (Queue_Tracker__c qt : [
            SELECT Id, Name, Last_Index__c 
            FROM Queue_Tracker__c 
            WHERE Name IN :queueNames
        ]) {
            trackerMap.put(qt.Name, qt);
        }
        
        List<Queue_Tracker__c> trackersToUpsert = new List<Queue_Tracker__c>();
        Map<Integer, Queue_Tracker__c> requestIndexToTrackerMap = new Map<Integer, Queue_Tracker__c>();
        
        // 4. First pass: Calculate indices and prepare tracker updates
        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            List<Id> members = queueToMembersMap.get(req.queueName);
            
            if (members == null || members.isEmpty()) {
                continue;
            }
            
            Queue_Tracker__c tracker = trackerMap.get(req.queueName);
            if (tracker == null) {
                tracker = new Queue_Tracker__c(Name = req.queueName, Last_Index__c = -1);
                trackerMap.put(req.queueName, tracker); // prevent duplicates in same batch
            }
            
            Integer lastIndex = (tracker.Last_Index__c == null) ? -1 : Integer.valueOf(tracker.Last_Index__c);
            Integer nextIndex = lastIndex + 1;
            
            if (nextIndex >= members.size()) {
                nextIndex = 0;
            }
            
            tracker.Last_Index__c = nextIndex;
            trackersToUpsert.add(tracker);
            requestIndexToTrackerMap.put(i, tracker); 
        }
        
        // 5. Commit all tracker index changes in ONE single DML statement
        if (!trackersToUpsert.isEmpty()) {
            upsert trackersToUpsert;
        }
        
        // 6. Bulk query assigned User details
        Set<Id> userIdsToQuery = new Set<Id>();
        for (Integer i = 0; i < requests.size(); i++) {
            List<Id> members = queueToMembersMap.get(requests[i].queueName);
            Queue_Tracker__c tracker = requestIndexToTrackerMap.get(i);
            if (members != null && tracker != null) {
                userIdsToQuery.add(members[Integer.valueOf(tracker.Last_Index__c)]);
            }
        }
        
        Map<Id, User> userMap = new Map<Id, User>([SELECT Email, FirstName, LastName FROM User WHERE Id IN :userIdsToQuery]);
        
        // 7. Final pass: Build the output results for the Flow
        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Result res = new Result();
            List<Id> members = queueToMembersMap.get(req.queueName);
            Queue_Tracker__c tracker = requestIndexToTrackerMap.get(i);
            
            if (members == null || members.isEmpty() || tracker == null) {
                res.assignedUserId = null; res.assignedUserEmail = null; res.assignedUserName = null;
                results.add(res);
                continue;
            }
            
            Id assignedUserId = members[Integer.valueOf(tracker.Last_Index__c)];
            User assignedUser = userMap.get(assignedUserId);
            
            if (assignedUser != null) {
                res.assignedUserId    = String.valueOf(assignedUserId);
                res.assignedUserEmail = assignedUser.Email;
                res.assignedUserName = (assignedUser.FirstName != null 
                        ? assignedUser.FirstName + ' ' 
                        : '') + assignedUser.LastName;            
            }
            
            results.add(res);
        }
        
        return results;
    }
    
    public class Request {
        @InvocableVariable(label='Queue API Name' required=true)
        public String queueName;
    }
    
    public class Result {
        @InvocableVariable(label='Assigned User Id')
        public String assignedUserId;
        @InvocableVariable(label='Assigned User Email')
        public String assignedUserEmail;
        @InvocableVariable(label='Assigned User Name')
        public String assignedUserName;
    }
}