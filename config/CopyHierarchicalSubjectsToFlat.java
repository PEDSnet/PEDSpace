package org.dspace.ctask.general;

import java.io.IOException;
import java.sql.SQLException;
import java.util.List;

import org.apache.commons.lang3.StringUtils;
import org.dspace.authorize.AuthorizeException;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.MetadataValue;
import org.dspace.content.service.ItemService;
import org.dspace.content.factory.ContentServiceFactory;
import org.dspace.core.Context;
import org.dspace.curate.AbstractCurationTask;
import org.dspace.curate.Curator;
import org.dspace.curate.Distributive;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A curation task that copies hierarchical subject terms from "dc.subject"
 * to "local.subject.flat" by extracting only the last node of the hierarchy.
 *
 * Example Hierarchy Value:
 * 
 * "Top::Mid::Leaf"
 * 
 * This task will extract "Leaf" and store it in "local.subject.flat".
 *
 * If an item already contains a {@code local.subject.flat} value identical to the
 * extracted one, it won’t be duplicated.
 *
 * Note: After adding this class, ensure that the DSpace backend
 * is rebuilt to compile and deploy the changes.
 * 
 * mvn package
 * ant update
 */

@Distributive
public class CopyHierarchicalSubjectsToFlat extends AbstractCurationTask {

    private static final Logger log = LoggerFactory.getLogger(CopyHierarchicalSubjectsToFlat.class);
    protected int status = Curator.CURATE_UNSET;
    private final ItemService itemService = ContentServiceFactory.getInstance().getItemService();

    @Override
    public int perform(DSpaceObject dso) throws IOException {
        // We only operate on Items
        if (!(dso instanceof Item)) {
            log.debug("Skipping non-Item object: {}", dso.getHandle());
            return Curator.CURATE_SKIP;
        }
        Item item = (Item) dso;
        Context context;
        try {
            context = Curator.curationContext();
        } catch (SQLException e) {
            log.error("Unable to get curation context for item: {}", item.getHandle(), e);
            throw new IOException("Unable to get curation context", e);
        }

        log.debug("Processing item: {}", item.getHandle());

        // Retrieve all dc.subject values
        List<MetadataValue> subjects = itemService.getMetadata(item, "dc", "subject", null, Item.ANY);

        if (subjects.isEmpty()) {
            // Nothing to process
            status = Curator.CURATE_SUCCESS;
            setResult("No dc.subject values present.");
            log.info("Item {} has no dc.subject values.", item.getHandle());
            return status;
        }

        // Retrieve existing local.subject.flat values once
        List<MetadataValue> existingFlats = itemService.getMetadata(item, "local", "subject", "flat", Item.ANY);
        log.debug("Existing local.subject.flat values: {}", existingFlats);

        // We'll process each subject and add flat versions
        boolean modified = false;
        for (MetadataValue subject : subjects) {
            String originalValue = subject.getValue();
            if (StringUtils.isBlank(originalValue)) {
                continue;
            }

            // Extract final node after the last "::"
            String flatValue = extractLastNode(originalValue);
            log.debug("Extracted flatValue: '{}' from originalValue: '{}'", flatValue, originalValue);

            // Check if this flatValue already exists
            boolean alreadyExists = existingFlats.stream()
                .anyMatch(val -> val.getValue().equals(flatValue));

            if (!alreadyExists) {
                // Add the extracted flat subject to the item
                try {
                    itemService.addMetadata(context, item, "local", "subject", "flat", null, flatValue);
                    log.info("Added local.subject.flat value '{}' to item {}", flatValue, item.getHandle());
                    modified = true;
                } catch (SQLException e) {
                    log.error("Error adding local.subject.flat to item: {}", item.getHandle(), e);
                    throw new IOException("Error adding local.subject.flat", e);
                }
            } else {
                log.debug("local.subject.flat value '{}' already exists for item {}", flatValue, item.getHandle());
            }
        }

        // If we changed the item, update it
        if (modified) {
            try {
                itemService.update(context, item);
                log.info("Updated item {} with new local.subject.flat values.", item.getHandle());
            } catch (SQLException | AuthorizeException e) {
                log.error("Error updating item: {}", item.getHandle(), e);
                throw new IOException("Error updating item", e);
            }
            status = Curator.CURATE_SUCCESS;
            setResult("Copied hierarchical subjects to local.subject.flat for item: " + item.getHandle());
        } else {
            status = Curator.CURATE_SUCCESS;
            setResult("No new local.subject.flat values added for item: " + item.getHandle());
            log.info("No new local.subject.flat values added for item {}", item.getHandle());
        }

        return status;
    }

    /**
     * Extract the final node after the last "::" separator.
     * If no "::" found, returns the original value.
     */
    private String extractLastNode(String value) {
        int lastIndex = value.lastIndexOf("::");
        if (lastIndex >= 0 && lastIndex < value.length() - 2) {
            return value.substring(lastIndex + 2).trim();
        }
        // If no "::" or it's at the end with no trailing text, return the full value
        return value.trim();
    }
}
